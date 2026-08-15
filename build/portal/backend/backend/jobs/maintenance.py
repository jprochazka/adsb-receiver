import logging

from datetime import datetime, timedelta, timezone
from flask import current_app
from flask_apscheduler import APScheduler
from sqlalchemy import delete, exists, or_, select

from backend.models import (
    Aircraft,
    Dump978Aircraft,
    Dump978Flight,
    Dump978Position,
    Flight,
    FlightComment,
    Position,
    Setting,
    UatFlightComment,
    AisPosition,
    AisRawMessage,
    AisTarget,
    AisVoyageReport,
    db,
)

scheduler = APScheduler()
DEFAULT_RETENTION_DAYS = 7300
AIS_RETENTION_DAYS = 30
AIS_RAW_RETENTION_DAYS = 7


class MaintenanceProcessor(object):
    def log(self, string):
        logging.info('[maintenance] %s', string)
        return

    def begin_maintenance(self):
        self.log("Getting maintenance settings from the database")

        if not self._is_purge_enabled():
            self.log("Maintenance is disabled")
            return

        cutoff_date = self._get_cutoff_date()
        if cutoff_date is None:
            return

        self.purge_aircraft(cutoff_date)
        self.purge_flights(cutoff_date)
        self.purge_positions(cutoff_date)
        self.purge_uat_aircraft(cutoff_date)
        self.purge_uat_flights(cutoff_date)
        self.purge_uat_positions(cutoff_date)
        self.purge_ais()

    def purge_ais(self):
        now = datetime.now(timezone.utc)
        position_cutoff = now - timedelta(days=AIS_RETENTION_DAYS)
        try:
            db.session.execute(delete(AisPosition).where(AisPosition.received_at < position_cutoff))
            db.session.execute(delete(AisVoyageReport).where(AisVoyageReport.reported_at < position_cutoff))
            db.session.execute(delete(AisRawMessage).where(AisRawMessage.expires_at < now))
            db.session.execute(delete(AisTarget).where(
                AisTarget.last_seen < position_cutoff,
                ~exists(select(1).where(AisPosition.target_id == AisTarget.id)),
                ~exists(select(1).where(AisVoyageReport.target_id == AisTarget.id)),
                ~exists(select(1).where(AisRawMessage.target_id == AisTarget.id)),
            ))
            self.log('Purged AIS history and expired raw messages')
        except Exception as ex:
            logging.error('Error purging AIS history', exc_info=ex)

    def _is_purge_enabled(self):
        try:
            setting = db.session.execute(
                select(Setting).filter_by(name='purge_older_data')
            ).scalar_one_or_none()
            return bool(setting and setting.value.lower() in ['true', '1'])
        except Exception as ex:
            logging.error("Error encountered while getting value for setting purge_older_data", exc_info=ex)
            return False

    def _get_cutoff_date(self):
        cutoff_date = datetime.now(timezone.utc) - timedelta(days=DEFAULT_RETENTION_DAYS)
        try:
            days_setting = db.session.execute(
                select(Setting).filter_by(name='days_to_save')
            ).scalar_one_or_none()
            if days_setting:
                try:
                    days = int(days_setting.value)
                except ValueError:
                    logging.error(
                        "Setting 'days_to_save' has non-integer value %r; using default %d days",
                        days_setting.value, DEFAULT_RETENTION_DAYS
                    )
                    return cutoff_date
                cutoff_date = datetime.now(timezone.utc) - timedelta(days=days)
            return cutoff_date
        except Exception as ex:
            logging.error("Error encountered while getting value for setting days_to_save", exc_info=ex)
            return None

    def _protected_flight_ids_subquery(self, flight_model):
        return select(flight_model.id).where(flight_model.ignore_on_purge.is_(True))

    def _delete_related_comments(self, flight_ids, comment_model, label, cutoff_date):
        if not flight_ids:
            return
        db.session.execute(delete(comment_model).where(comment_model.flight_id.in_(flight_ids)))

    def _delete_related_positions(self, flight_ids, position_model, label, cutoff_date):
        if not flight_ids:
            return
        db.session.execute(delete(position_model).where(position_model.flight.in_(flight_ids)))

    def _delete_positions_for_aircraft(self, aircraft_ids, position_model, flight_model, label, cutoff_date, include_orphans=False):
        if not aircraft_ids:
            return

        protected_flight_ids = self._protected_flight_ids_subquery(flight_model)
        condition = ~position_model.flight.in_(protected_flight_ids)
        if include_orphans:
            condition = or_(position_model.flight.is_(None), condition)

        try:
            db.session.execute(
                delete(position_model).where(
                    position_model.aircraft.in_(aircraft_ids),
                    condition,
                )
            )
        except Exception as ex:
            logging.error(f"Error deleting {label} positions related to aircraft not seen since {cutoff_date}", exc_info=ex)

    def _delete_flights_for_aircraft(self, aircraft_ids, flight_model, comment_model, label, cutoff_date):
        if not aircraft_ids:
            return

        try:
            flight_ids = db.session.execute(
                select(flight_model.id).where(
                    flight_model.aircraft.in_(aircraft_ids),
                    flight_model.ignore_on_purge.is_(False),
                )
            ).scalars().all()
        except Exception as ex:
            logging.error(f"Error deleting {label} flights related to aircraft not seen since {cutoff_date}", exc_info=ex)
            return

        self._delete_related_comments(flight_ids, comment_model, label, cutoff_date)

        try:
            db.session.execute(
                delete(flight_model).where(
                    flight_model.aircraft.in_(aircraft_ids),
                    flight_model.ignore_on_purge.is_(False),
                )
            )
        except Exception as ex:
            logging.error(f"Error deleting {label} flights related to aircraft not seen since {cutoff_date}", exc_info=ex)

    def _purge_aircraft_family(self, aircraft_model, flight_model, position_model, comment_model, label, cutoff_date, include_orphans=False):
        cutoff_str = str(cutoff_date)

        try:
            old_aircraft_result = db.session.execute(
                select(aircraft_model).filter(
                    aircraft_model.last_seen < cutoff_str,
                    ~exists(select(1).where(
                        flight_model.aircraft == aircraft_model.id,
                        flight_model.ignore_on_purge.is_(True),
                    )),
                )
            )
            aircraft_ids = [aircraft.id for aircraft in old_aircraft_result.scalars()]
        except Exception as ex:
            logging.error(f"Error encountered while getting {label} aircraft IDs not seen since {cutoff_date}", exc_info=ex)
            return

        if not aircraft_ids:
            return

        self.log(f"Purging {len(aircraft_ids)} {label} aircraft not seen since {cutoff_date}")

        try:
            self._delete_flights_for_aircraft(aircraft_ids, flight_model, comment_model, label, cutoff_date)
            self._delete_positions_for_aircraft(aircraft_ids, position_model, flight_model, label, cutoff_date, include_orphans)
            db.session.execute(delete(aircraft_model).where(aircraft_model.id.in_(aircraft_ids)))
        except Exception as ex:
            logging.error(f"Error deleting {label} aircraft not seen since {cutoff_date}", exc_info=ex)

    def _purge_flight_family(self, flight_model, position_model, comment_model, label, cutoff_date):
        cutoff_str = str(cutoff_date)

        try:
            old_flights_result = db.session.execute(
                select(flight_model.id).filter(
                    flight_model.last_seen < cutoff_str,
                    flight_model.ignore_on_purge.is_(False),
                )
            )
            flight_ids = old_flights_result.scalars().all()
        except Exception as ex:
            logging.error(f"Error encountered while getting {label} flight IDs not seen since {cutoff_date}", exc_info=ex)
            return

        if not flight_ids:
            return

        self.log(f"Purging {len(flight_ids)} {label} flights not seen since {cutoff_date}")

        try:
            self._delete_related_positions(flight_ids, position_model, label, cutoff_date)
            self._delete_related_comments(flight_ids, comment_model, label, cutoff_date)
            db.session.execute(delete(flight_model).where(flight_model.id.in_(flight_ids)))
        except Exception as ex:
            logging.error(f"Error deleting {label} flights older than the cut off date of {cutoff_date}", exc_info=ex)

    def _purge_old_positions(self, position_model, flight_model, label, cutoff_date, include_orphans=False):
        cutoff_str = str(cutoff_date)
        protected_flight_ids = self._protected_flight_ids_subquery(flight_model)
        condition = ~position_model.flight.in_(protected_flight_ids)
        if include_orphans:
            condition = or_(position_model.flight.is_(None), condition)

        try:
            db.session.execute(
                delete(position_model).where(
                    position_model.time < cutoff_str,
                    condition,
                )
            )
            self.log(f"Purged {label} positions older than {cutoff_date}")
        except Exception as ex:
            logging.error(f"Error deleting {label} positions older than the cut off date of {cutoff_date}", exc_info=ex)

    def purge_aircraft(self, cutoff_date):
        self._purge_aircraft_family(Aircraft, Flight, Position, FlightComment, 'ADS-B', cutoff_date)

    def purge_flights_related_to_aircraft(self, aircraft_ids, cutoff_date):
        self._delete_flights_for_aircraft(aircraft_ids, Flight, FlightComment, 'ADS-B', cutoff_date)

    def purge_positions_related_to_aircraft(self, aircraft_ids, cutoff_date):
        self._delete_positions_for_aircraft(aircraft_ids, Position, Flight, 'ADS-B', cutoff_date)

    def purge_flights(self, cutoff_date):
        self._purge_flight_family(Flight, Position, FlightComment, 'ADS-B', cutoff_date)

    def purge_comments_related_to_flights(self, flight_ids, cutoff_date):
        self._delete_related_comments(flight_ids, FlightComment, 'ADS-B', cutoff_date)

    def purge_positions_related_to_flights(self, flight_ids, cutoff_date):
        self._delete_related_positions(flight_ids, Position, 'ADS-B', cutoff_date)

    def purge_positions(self, cutoff_date):
        self._purge_old_positions(Position, Flight, 'ADS-B', cutoff_date)

    def purge_uat_aircraft(self, cutoff_date):
        self._purge_aircraft_family(
            Dump978Aircraft,
            Dump978Flight,
            Dump978Position,
            UatFlightComment,
            'UAT',
            cutoff_date,
            include_orphans=True,
        )

    def purge_uat_flights_related_to_aircraft(self, aircraft_ids, cutoff_date):
        self._delete_flights_for_aircraft(aircraft_ids, Dump978Flight, UatFlightComment, 'UAT', cutoff_date)

    def purge_uat_positions_related_to_aircraft(self, aircraft_ids, cutoff_date):
        self._delete_positions_for_aircraft(
            aircraft_ids,
            Dump978Position,
            Dump978Flight,
            'UAT',
            cutoff_date,
            include_orphans=True,
        )

    def purge_uat_flights(self, cutoff_date):
        self._purge_flight_family(Dump978Flight, Dump978Position, UatFlightComment, 'UAT', cutoff_date)

    def purge_uat_comments_related_to_flights(self, flight_ids, cutoff_date):
        self._delete_related_comments(flight_ids, UatFlightComment, 'UAT', cutoff_date)

    def purge_uat_positions_related_to_flights(self, flight_ids, cutoff_date):
        self._delete_related_positions(flight_ids, Dump978Position, 'UAT', cutoff_date)

    def purge_uat_positions(self, cutoff_date):
        self._purge_old_positions(Dump978Position, Dump978Flight, 'UAT', cutoff_date, include_orphans=True)

def maintenance_job():
    """Main maintenance job function."""
    with current_app.app_context():
        processor = MaintenanceProcessor()

        # Setup and begin the maintenance job
        processor.log("-- BEGINNING PORTAL MAINTENANCE JOB")
        processor.begin_maintenance()
        
        # Commit all changes
        try:
            db.session.commit()
            processor.log("-- Database changes committed successfully")
        except Exception as ex:
            db.session.rollback()
            logging.error("Error committing database changes", exc_info=ex)
        
        processor.log("-- PORTAL MAINTENANCE JOB COMPLETE")