import logging
import os
import psutil
import yaml

from flask import abort, Blueprint, current_app, jsonify
from flask_restx import Namespace, Resource, fields as restx_fields
from backend.models import db
from backend.auth import require_admin

with open("config.yml") as _f:
    config = yaml.safe_load(_f)


system = Blueprint('system', __name__)

# Create Flask-RESTX namespace for system monitoring
system_ns = Namespace('system', description='System monitoring and health checks')

# Define API models for documentation
cpu_model = system_ns.model('CPUInfo', {
    'cpu_percent': restx_fields.Float(description='CPU usage percentage'),
    'cpu_count': restx_fields.Integer(description='Number of CPU cores'),
    'cpu_freq': restx_fields.Raw(description='CPU frequency information')
})

memory_model = system_ns.model('MemoryInfo', {
    'total': restx_fields.Integer(description='Total memory in bytes'),
    'available': restx_fields.Integer(description='Available memory in bytes'),
    'percent': restx_fields.Float(description='Memory usage percentage'),
    'used': restx_fields.Integer(description='Used memory in bytes'),
    'free': restx_fields.Integer(description='Free memory in bytes')
})

disk_model = system_ns.model('DiskInfo', {
    'total': restx_fields.Integer(description='Total disk space in bytes'),
    'used': restx_fields.Integer(description='Used disk space in bytes'),
    'free': restx_fields.Integer(description='Free disk space in bytes'),
    'percent': restx_fields.Float(description='Disk usage percentage')
})

network_model = system_ns.model('NetworkInfo', {
    'bytes_sent': restx_fields.Integer(description='Bytes sent'),
    'bytes_recv': restx_fields.Integer(description='Bytes received'),
    'packets_sent': restx_fields.Integer(description='Packets sent'),
    'packets_recv': restx_fields.Integer(description='Packets received')
})

database_model = system_ns.model('DatabaseInfo', {
    'type': restx_fields.String(description='Database type'),
    'size': restx_fields.Integer(description='Database size in bytes'),
    'tables': restx_fields.Integer(description='Number of tables')
})

flights_tables_model = system_ns.model('FlightsTablesInfo', {
    'size': restx_fields.Integer(description='Combined size of flight tables in bytes'),
})


@system_ns.route('/cpu')
class CPUResource(Resource):
    @system_ns.response(200, 'CPU information retrieved successfully')
    @system_ns.response(401, 'Unauthorized')
    @system_ns.response(403, 'Forbidden')
    @system_ns.response(500, 'Internal server error')
    @system_ns.doc('get_cpu_info', security='Bearer')
    @require_admin()
    def get(self):
        """Get CPU information and statistics"""
        try:
            frequency = psutil.cpu_freq()
            stats = psutil.cpu_stats()
            cpu_data = {
                'cpu_count': psutil.cpu_count(),
                'cpu_count_logical': psutil.cpu_count(True),
                'cpu_frequency_current': frequency.current,
                'cpu_frequency_max': frequency.max,
                'cpu_frequency_min': frequency.min,
                'cpu_load_averages': psutil.getloadavg(),
                'cpu_percent': psutil.cpu_percent(1),
                'cpu_stats_context_switches_since_boot': stats.ctx_switches,
                'cpu_stats_interupts_since_boot': stats.interrupts,
                'cpu_stats_soft_interupts_since_boot': stats.soft_interrupts,
                'cpu_stats_system_calls_since_boot': stats.syscalls,
                'cpu_times': psutil.cpu_times()._asdict(),
                'cpu_times_percent': psutil.cpu_times_percent(1)._asdict()
            }
            return jsonify(cpu_data)
        except Exception as e:
            logging.error(f'Error encountered while getting CPU information: {e}')
            return {'msg': 'Internal Server Error'}, 500


@system_ns.route('/memory')
class MemoryResource(Resource):
    @system_ns.response(200, 'Memory information retrieved successfully')
    @system_ns.response(401, 'Unauthorized')
    @system_ns.response(403, 'Forbidden')
    @system_ns.response(500, 'Internal server error')
    @system_ns.doc('get_memory_info', security='Bearer')
    @require_admin()
    def get(self):
        """Get memory usage information"""
        try:
            virtual = psutil.virtual_memory()
            swap = psutil.swap_memory()
            memory_data = {
                'memory_virtual_total': virtual.total,
                'memory_virtual_available': virtual.available,
                'memory_virtual_percent': virtual.percent,
                'memory_virtual_used': virtual.used,
                'memory_virtual_free': virtual.free,
                'memory_swap_total': swap.total,
                'memory_swap_used': swap.used,
                'memory_swap_free': swap.free,
                'memory_swap_percent': swap.percent,
                'memory_swap_sin': swap.sin,
                'memory_swap_sout': swap.sout,
            }
            return jsonify(memory_data)
        except Exception as e:
            logging.error(f'Error encountered while getting memory information: {e}')
            return {'msg': 'Internal Server Error'}, 500


@system_ns.route('/disk')
class DiskResource(Resource):
    @system_ns.response(200, 'Disk information retrieved successfully')
    @system_ns.response(401, 'Unauthorized')
    @system_ns.response(403, 'Forbidden')
    @system_ns.response(500, 'Internal server error')
    @system_ns.doc('get_disk_info', security='Bearer')
    @require_admin()
    def get(self):
        """Get disk usage information"""
        try:
            usage = psutil.disk_usage('/')
            io = psutil.disk_io_counters()
            disk_data = {
                'disk_usage_total': usage.total,
                'disk_usage_used': usage.used,
                'disk_usage_free': usage.free,
                'disk_usage_percent': usage.percent,
                'disk_io_read_count': io.read_count,
                'disk_io_write_count': io.write_count,
                'disk_io_read_bytes': io.read_bytes,
                'disk_io_write_bytes': io.write_bytes,
                'disk_partitions': [p._asdict() for p in psutil.disk_partitions()],
            }
            return jsonify(disk_data)
        except Exception as e:
            logging.error(f'Error encountered while getting disk information: {e}')
            return {'msg': 'Internal Server Error'}, 500


@system_ns.route('/network')
class NetworkResource(Resource):
    @system_ns.response(200, 'Network information retrieved successfully')
    @system_ns.response(401, 'Unauthorized')
    @system_ns.response(403, 'Forbidden')
    @system_ns.response(500, 'Internal server error')
    @system_ns.doc('get_network_info', security='Bearer')
    @require_admin()
    def get(self):
        """Get network usage information"""
        try:
            io = psutil.net_io_counters()
            network_data = {
                'network_io_bytes_sent': io.bytes_sent,
                'network_io_bytes_received': io.bytes_recv,
                'network_io_packets_sent': io.packets_sent,
                'network_io_packets_received': io.packets_recv,
                'network_io_errors_in': io.errin,
                'network_io_errors_out': io.errout,
                'network_io_dropped_in': io.dropin,
                'network_io_dropped_out': io.dropout,
                'network_connections': psutil.net_connections(),
                'network_interface_addresses': psutil.net_if_addrs(),
                'network_interface_stats': psutil.net_if_stats()
            }
            return jsonify(network_data)
        except Exception as e:
            logging.error(f'Error encountered while getting network information: {e}')
            return {'msg': 'Internal Server Error'}, 500


@system_ns.route('/sensors')
class SensorsResource(Resource):
    @system_ns.response(200, 'Success')
    @system_ns.response(401, 'Unauthorized')
    @system_ns.response(403, 'Forbidden')
    @system_ns.response(500, 'Internal server error')
    @system_ns.doc('get_sensors_info', security='Bearer')
    @require_admin()
    def get(self):
        """Get sensor information (battery, temperature)"""
        try:
            battery = psutil.sensors_battery()
            sensor_data = {
                'sensors_battery': battery._asdict() if battery else None,
            }
            return jsonify(sensor_data)
        except Exception as e:
            logging.error(f'Error encountered while getting sensor information: {e}')
            return {'msg': 'Internal Server Error'}, 500


@system_ns.route('/other')
class OtherResource(Resource):
    @system_ns.response(200, 'Success')
    @system_ns.response(401, 'Unauthorized')
    @system_ns.response(403, 'Forbidden')
    @system_ns.response(500, 'Internal server error')
    @system_ns.doc('get_other_info', security='Bearer')
    @require_admin()
    def get(self):
        """Get other system information (boot time, users)"""
        try:
            other_data = {
                'other_boot_time': psutil.boot_time(),
                'other_users': [u._asdict() for u in psutil.users()]
            }
            return jsonify(other_data)
        except Exception as e:
            logging.error(f'Error encountered while getting other system information: {e}')
            return {'msg': 'Internal Server Error'}, 500


@system_ns.route('/database')
class DatabaseResource(Resource):
    @system_ns.response(200, 'Database information retrieved successfully')
    @system_ns.response(401, 'Unauthorized')
    @system_ns.response(403, 'Forbidden')
    @system_ns.response(500, 'Internal server error')
    @system_ns.doc('get_database_info', security='Bearer')
    @require_admin()
    def get(self):
        """Get database size and information"""
        try:
            match config['database']['use'].lower():
                case 'mysql':
                    result = db.session.execute(
                        db.text("SELECT SUM(data_length + index_length) AS size FROM information_schema.tables WHERE table_schema = :db_name GROUP BY table_schema"),
                        {"db_name": config['database']['mysql']['database']}
                    )
                    db_size = result.fetchone()[0]
                case 'postgresql':
                    result = db.session.execute(
                        db.text("SELECT pg_database_size(:db_name)"),
                        {"db_name": config['database']['postgresql']['database']}
                    )
                    db_size = result.fetchone()[0]
                case 'sqlite':
                    db_size = os.path.getsize(os.path.join(current_app.instance_path, 'adsbportal.sqlite3'))
            return jsonify({'size': db_size})
        except Exception as e:
            logging.error(f'Error encountered while getting database information: {e}')
            return {'msg': 'Internal Server Error'}, 500


_FLIGHT_TABLES = [
    'dump1090_aircraft', 'dump1090_flights', 'dump1090_positions',
    'dump978_aircraft', 'dump978_flights', 'dump978_positions',
]


@system_ns.route('/flights-tables')
class FlightsTablesResource(Resource):
    @system_ns.marshal_with(flights_tables_model, code=200)
    @system_ns.response(200, 'Flight table size retrieved successfully')
    @system_ns.response(401, 'Unauthorized')
    @system_ns.response(403, 'Forbidden')
    @system_ns.response(500, 'Internal server error')
    @system_ns.doc('get_flights_tables_size', security='Bearer')
    @require_admin()
    def get(self):
        """Get combined disk size used by all flight-related tables"""
        try:
            db_type = config['database']['use'].lower()
            match db_type:
                case 'mysql':
                    placeholders = ', '.join(f':t{i}' for i in range(len(_FLIGHT_TABLES)))
                    params = {f't{i}': t for i, t in enumerate(_FLIGHT_TABLES)}
                    params['db_name'] = config['database']['mysql']['database']
                    result = db.session.execute(
                        db.text(
                            f"SELECT SUM(data_length + index_length) FROM information_schema.tables "
                            f"WHERE table_schema = :db_name AND table_name IN ({placeholders})"
                        ),
                        params
                    )
                    size = result.fetchone()[0] or 0
                case 'postgresql':
                    parts = ' + '.join(
                        f"pg_total_relation_size('{t}')" for t in _FLIGHT_TABLES
                    )
                    result = db.session.execute(db.text(f"SELECT {parts}"))
                    size = result.fetchone()[0] or 0
                case 'sqlite':
                    placeholders = ', '.join(f"'{t}'" for t in _FLIGHT_TABLES)
                    result = db.session.execute(
                        db.text(f"SELECT SUM(pgsize) FROM dbstat WHERE name IN ({placeholders})")
                    )
                    size = result.fetchone()[0] or 0
            return {'size': size}, 200
        except Exception as e:
            logging.error(f'Error retrieving flights table size: {e}')
            return {'msg': 'Internal Server Error'}, 500




