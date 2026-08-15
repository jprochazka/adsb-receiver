import argparse
import datetime
import json
import logging
import signal
import socket
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


DEFAULT_DATABASE_PATH = '/var/lib/adsb-receiver/acars.sqlite3'
DEFAULT_BIND_ADDRESS = '127.0.0.1'
DEFAULT_PORT = 5555


@dataclass(frozen=True)
class AcarsMessage:
    timestamp: float
    station_id: str
    channel: int
    error: int
    signal_level: float
    mode: str
    acknowledgement: str
    label: str
    block_number: str
    message_number: str
    text: str
    registration: str
    flight_number: str


def _as_text(value) -> str:
    if value is None or value is False:
        return ''
    return str(value).strip()


def _as_timestamp(value) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        normalized = value.strip().replace('Z', '+00:00')
        try:
            return float(normalized)
        except ValueError:
            return datetime.datetime.fromisoformat(normalized).timestamp()
    raise ValueError('Message timestamp is missing or invalid')


def _as_channel(value) -> int:
    frequency = float(value or 0)
    if 0 < frequency < 1_000_000:
        frequency *= 1_000_000
    return round(frequency)


def _as_error(value, *, crc_ok=None) -> int:
    if crc_ok is False:
        return 1
    if value in (None, False, 0, '0', '', 'false', 'False', 'no error'):
        return 0
    try:
        return int(value)
    except (TypeError, ValueError):
        return 1


def _parse_flat_message(payload: dict) -> AcarsMessage:
    return AcarsMessage(
        timestamp=_as_timestamp(payload.get('timestamp')),
        station_id=_as_text(payload.get('station_id')) or 'acarsdec',
        channel=_as_channel(payload.get('freq', payload.get('channel'))),
        error=_as_error(payload.get('error')),
        signal_level=float(payload.get('level') or 0),
        mode=_as_text(payload.get('mode'))[:1],
        acknowledgement=_as_text(payload.get('ack'))[:1],
        label=_as_text(payload.get('label'))[:2],
        block_number=_as_text(payload.get('block_id'))[:1],
        message_number=_as_text(payload.get('msgno'))[:4],
        text=_as_text(payload.get('text'))[:250],
        registration=_as_text(payload.get('tail'))[:7],
        flight_number=_as_text(payload.get('flight'))[:6],
    )


def _parse_dumpvdl2_message(payload: dict) -> Optional[AcarsMessage]:
    vdl2 = payload.get('vdl2')
    if not isinstance(vdl2, dict):
        return None

    avlc = vdl2.get('avlc')
    acars = avlc.get('acars') if isinstance(avlc, dict) else None
    if not isinstance(acars, dict):
        return None

    timestamp = vdl2.get('t')
    if not isinstance(timestamp, dict):
        raise ValueError('dumpvdl2 timestamp is missing')

    seconds = _as_timestamp(timestamp.get('sec'))
    microseconds = float(timestamp.get('usec') or 0)
    message_number = f"{_as_text(acars.get('msg_num'))}{_as_text(acars.get('msg_num_seq'))}"

    return AcarsMessage(
        timestamp=seconds + microseconds / 1_000_000,
        station_id=_as_text(vdl2.get('station')) or 'dumpvdl2',
        channel=_as_channel(vdl2.get('freq')),
        error=_as_error(acars.get('err'), crc_ok=acars.get('crc_ok')),
        signal_level=float(vdl2.get('sig_level') or 0),
        mode=_as_text(acars.get('mode'))[:1],
        acknowledgement=_as_text(acars.get('ack'))[:1],
        label=_as_text(acars.get('label'))[:2],
        block_number=_as_text(acars.get('blk_id'))[:1],
        message_number=message_number[:4],
        text=_as_text(acars.get('msg_text'))[:250],
        registration=_as_text(acars.get('reg'))[:7],
        flight_number=_as_text(acars.get('flight'))[:6],
    )


def parse_message(payload: dict) -> Optional[AcarsMessage]:
    if not isinstance(payload, dict):
        raise ValueError('Message payload must be a JSON object')
    if 'vdl2' in payload:
        return _parse_dumpvdl2_message(payload)
    return _parse_flat_message(payload)


class AcarsDatabase:
    def __init__(self, database_path: str):
        self.database_path = Path(database_path)
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self.connection = sqlite3.connect(self.database_path, timeout=30)
        self.connection.execute('PRAGMA journal_mode=WAL')
        self.connection.execute('PRAGMA busy_timeout=30000')
        self._initialize_schema()

    def close(self):
        self.connection.close()

    def _initialize_schema(self):
        self.connection.executescript(
            '''
            CREATE TABLE IF NOT EXISTS Flights (
                FlightID INTEGER PRIMARY KEY,
                Registration CHAR(7),
                FlightNumber CHAR(6),
                StartTime DATETIME,
                LastTime DATETIME,
                NbMessages INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS FlightsFlightNumber ON Flights(FlightNumber);
            CREATE INDEX IF NOT EXISTS FlightsRegistration ON Flights(Registration);
            CREATE TABLE IF NOT EXISTS Stations (
                StID INTEGER PRIMARY KEY,
                IdStation VARCHAR,
                IpAddr VARCHAR
            );
            CREATE TABLE IF NOT EXISTS Messages (
                MessageID INTEGER PRIMARY KEY,
                FlightID INTEGER NOT NULL,
                Time DATETIME,
                StID INTEGER,
                Channel INTEGER,
                Error INTEGER,
                SignalLvl REAL,
                Mode CHAR,
                Ack CHAR,
                Label CHAR(2),
                BlockNo CHAR,
                MessNo CHAR(4),
                Txt VARCHAR(250)
            );
            '''
        )
        self.connection.commit()

    def store(self, message: AcarsMessage, source_address: str) -> bool:
        if not message.registration or not message.flight_number:
            return False

        received_at = datetime.datetime.fromtimestamp(
            message.timestamp, datetime.timezone.utc
        ).strftime('%Y-%m-%d %H:%M:%S')

        with self.connection:
            station_id = self._station_id(source_address, message.station_id)
            flight_id = self._flight_id(message, received_at)

            if message.message_number:
                duplicate = self.connection.execute(
                    'SELECT 1 FROM Messages WHERE FlightID = ? AND MessNo = ? LIMIT 1',
                    (flight_id, message.message_number),
                ).fetchone()
                if duplicate:
                    return False

            self.connection.execute(
                '''
                INSERT INTO Messages
                    (FlightID, Time, StID, Channel, Error, SignalLvl, Mode, Ack,
                     Label, BlockNo, MessNo, Txt)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''',
                (
                    flight_id,
                    received_at,
                    station_id,
                    message.channel,
                    message.error,
                    message.signal_level,
                    message.mode,
                    message.acknowledgement,
                    message.label,
                    message.block_number,
                    message.message_number,
                    message.text,
                ),
            )
            if flight_id:
                self.connection.execute(
                    '''
                    UPDATE Flights
                    SET LastTime = ?, NbMessages = NbMessages + 1
                    WHERE FlightID = ?
                    ''',
                    (received_at, flight_id),
                )
        return True

    def _station_id(self, source_address: str, station_name: str) -> int:
        row = self.connection.execute(
            'SELECT StID FROM Stations WHERE IpAddr = ? AND IdStation = ?',
            (source_address, station_name),
        ).fetchone()
        if row:
            return row[0]

        cursor = self.connection.execute(
            'INSERT INTO Stations (IpAddr, IdStation) VALUES (?, ?)',
            (source_address, station_name),
        )
        return cursor.lastrowid

    def _flight_id(self, message: AcarsMessage, received_at: str) -> int:
        if not message.registration or not message.flight_number:
            return 0

        row = self.connection.execute(
            '''
            SELECT FlightID
            FROM Flights
            WHERE Registration = ?
              AND FlightNumber = ?
              AND datetime(LastTime, '30 minutes') > datetime(?)
            ORDER BY LastTime DESC
            LIMIT 1
            ''',
            (message.registration, message.flight_number, received_at),
        ).fetchone()
        if row:
            return row[0]

        cursor = self.connection.execute(
            '''
            INSERT INTO Flights
                (Registration, FlightNumber, StartTime, LastTime, NbMessages)
            VALUES (?, ?, ?, ?, 0)
            ''',
            (
                message.registration,
                message.flight_number,
                received_at,
                received_at,
            ),
        )
        return cursor.lastrowid


class AcarsIngestServer:
    def __init__(self, database: AcarsDatabase, bind_address: str, port: int):
        self.database = database
        self.bind_address = bind_address
        self.port = port
        self.running = True

    def stop(self, *_args):
        self.running = False

    def serve(self):
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as server:
            server.bind((self.bind_address, self.port))
            server.settimeout(1)
            logging.info('Listening for ACARS JSON on %s:%s', self.bind_address, self.port)
            while self.running:
                try:
                    packet, source = server.recvfrom(65535)
                except (socket.timeout, TimeoutError):
                    continue

                try:
                    payload = json.loads(packet.decode('utf-8'))
                    message = parse_message(payload)
                    if message is not None:
                        self.database.store(message, source[0])
                except (UnicodeDecodeError, json.JSONDecodeError, TypeError, ValueError) as ex:
                    logging.warning('Discarding invalid ACARS JSON: %s', ex)
                except sqlite3.Error:
                    logging.exception('Failed storing ACARS message')


def main():
    parser = argparse.ArgumentParser(description='Store ACARS and dumpvdl2 JSON in SQLite')
    parser.add_argument('--database', default=DEFAULT_DATABASE_PATH)
    parser.add_argument('--bind', default=DEFAULT_BIND_ADDRESS)
    parser.add_argument('--port', default=DEFAULT_PORT, type=int)
    args = parser.parse_args()

    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s %(levelname)s %(message)s',
    )
    database = AcarsDatabase(args.database)
    server = AcarsIngestServer(database, args.bind, args.port)
    signal.signal(signal.SIGTERM, server.stop)
    signal.signal(signal.SIGINT, server.stop)
    try:
        server.serve()
    finally:
        database.close()


if __name__ == '__main__':
    main()
