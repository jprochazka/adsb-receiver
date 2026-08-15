import pytest

from backend.acars_ingest import AcarsDatabase, parse_message


@pytest.fixture
def acars_database(tmp_path):
    database = AcarsDatabase(str(tmp_path / 'acars.sqlite3'))
    yield database
    database.close()


def test_parse_flat_acarsdec_message():
    message = parse_message({
        'timestamp': 1_700_000_000,
        'station_id': 'KSEA',
        'freq': 131.550,
        'level': -21,
        'error': 0,
        'mode': '2',
        'ack': 'A',
        'label': 'H1',
        'block_id': '1',
        'msgno': 'M01A',
        'text': 'TEST MESSAGE',
        'tail': 'N12345',
        'flight': 'DAL123',
    })

    assert message is not None
    assert message.channel == 131_550_000
    assert message.error == 0
    assert message.registration == 'N12345'
    assert message.flight_number == 'DAL123'


def test_parse_nested_dumpvdl2_message():
    message = parse_message({
        'vdl2': {
            'station': 'KSEA-VDL2',
            't': {'sec': 1_700_000_000, 'usec': 500_000},
            'freq': 136_975_000,
            'sig_level': -17.5,
            'avlc': {
                'acars': {
                    'crc_ok': True,
                    'err': False,
                    'mode': '2',
                    'reg': 'N54321',
                    'ack': 'A',
                    'label': 'B1',
                    'blk_id': '2',
                    'msg_num': 'M02',
                    'msg_num_seq': 'B',
                    'flight': 'UAL456',
                    'msg_text': 'VDL2 MESSAGE',
                }
            },
        }
    })

    assert message is not None
    assert message.timestamp == 1_700_000_000.5
    assert message.message_number == 'M02B'
    assert message.text == 'VDL2 MESSAGE'
    assert message.error == 0


def test_ignore_dumpvdl2_frame_without_acars():
    assert parse_message({
        'vdl2': {
            't': {'sec': 1_700_000_000, 'usec': 0},
            'avlc': {'frame_type': 'I'},
        }
    }) is None


def test_store_message_in_legacy_portal_schema(acars_database):
    message = parse_message({
        'vdl2': {
            'station': 'KSEA-VDL2',
            't': {'sec': 1_700_000_000, 'usec': 0},
            'freq': 136_975_000,
            'sig_level': -10,
            'avlc': {
                'acars': {
                    'crc_ok': True,
                    'mode': '2',
                    'reg': 'N54321',
                    'ack': 'A',
                    'label': 'B1',
                    'blk_id': '2',
                    'msg_num': 'M02',
                    'msg_num_seq': 'B',
                    'flight': 'UAL456',
                    'msg_text': 'VDL2 MESSAGE',
                }
            },
        }
    })

    assert acars_database.store(message, '127.0.0.1') is True
    assert acars_database.store(message, '127.0.0.1') is False

    flight = acars_database.connection.execute(
        'SELECT Registration, FlightNumber, NbMessages FROM Flights'
    ).fetchone()
    stored_message = acars_database.connection.execute(
        'SELECT Channel, Label, MessNo, Txt FROM Messages'
    ).fetchone()
    station = acars_database.connection.execute(
        'SELECT IdStation, IpAddr FROM Stations'
    ).fetchone()

    assert flight == ('N54321', 'UAL456', 1)
    assert stored_message == (136_975_000, 'B1', 'M02B', 'VDL2 MESSAGE')
    assert station == ('KSEA-VDL2', '127.0.0.1')


def test_reject_message_without_timestamp():
    with pytest.raises(ValueError, match='timestamp'):
        parse_message({'flight': 'DAL123'})


def test_preserve_acarsdec_error_count():
    message = parse_message({
        'timestamp': 1_700_000_000,
        'error': 3,
        'tail': 'N12345',
        'flight': 'DAL123',
    })

    assert message is not None
    assert message.error == 3


def test_skip_message_without_flight_metadata(acars_database):
    message = parse_message({
        'timestamp': 1_700_000_000,
        'tail': 'N12345',
        'text': 'UPLINK',
    })

    assert message is not None
    assert acars_database.store(message, '127.0.0.1') is False
    assert acars_database.connection.execute(
        'SELECT COUNT(*) FROM Messages'
    ).fetchone()[0] == 0
