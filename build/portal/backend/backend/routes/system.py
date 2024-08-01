import logging
import os
import psutil
import yaml

from flask import  abort, Blueprint, current_app, jsonify
from backend.db import get_db

config=yaml.safe_load(open("config.yml"))


system = Blueprint('system', __name__)

@system.route("/api/system/cpu", methods=["GET"])
def cpu():
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
        'cpu_times': psutil.cpu_times(),
        'cpu_times_percent': psutil.cpu_times_percent(1)
    }

    response=jsonify(cpu_data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@system.route("/api/system/memory", methods=["GET"])
def memory():
    virtual = psutil.virtual_memory()
    swap = psutil.swap_memory()
    memory_data = {
        'memory_virtual_total': virtual.total,
        'memory_virtual_available': virtual.available,
        'memory_virtual_percent': virtual.available,
        'memory_virtual_used': virtual.used,
        'memory_virtual_free': virtual.free,
        'memory_swap_total': swap.total,
        'memory_swap_used': swap.used,
        'memory_swap_free': swap.free,
        'memory_swap_percent': swap.percent,
        'memory_swap_sin': swap.sin,
        'memory_swap_sout': swap.sout,
    }
    response=jsonify(memory_data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@system.route("/api/system/disk", methods=["GET"])
def disk():
    usage = psutil.disk_usage('/')
    io = psutil.disk_io_counters()
    disk_data = {
        'disk_usage_total': usage.total,
        'disk_usage_used': usage.used,
        'disk_usage_free': usage.free,
        'disk_usage_percent': usage.percent,
        'disk_io_read_count': io.read_count,
        'disk_usage_percent': io.write_count,
        'disk_usage_percent': io.read_bytes,
        'disk_usage_percent': io.write_bytes,
        'disk_usage_percent': io.read_count,
        'disk_partitions': psutil.disk_partitions(),
    }

    response=jsonify(disk_data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@system.route("/api/system/network", methods=["GET"])
def network():
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

    response=jsonify(network_data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@system.route("/api/system/sensors", methods=["GET"])
def sensors():
    sensor_data = {
        #'sensors_temperature': psutil.sensors_temperatures(True),
        #'sensors_fans': psutil.sensors_fans(),
        'sensors_battery': psutil.sensors_battery(),
        #'sensor_temperatures': psutil.sensors_temperatures()['cpu-thermal'][0].current
    }

    response=jsonify(sensor_data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@system.route("/api/system/other", methods=["GET"])
def other():
    other_data = {
        'other_boot_time': psutil.boot_time(),
        'other_users': psutil.users()
    }

    response=jsonify(other_data)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

@system.route("/api/system/database", methods=["GET"])
def database():
    match config['database']['use'].lower():
            case 'mysql':
                try:
                    db=get_db()
                    cursor=db.cursor()
                    cursor.execute("SELECT SUM(data_length + index_length) AS size FROM information_schema.tables WHERE table_schema = %s GROUP BY table_schema;", (config['database']['mysql']['database'],))
                    db_size=cursor.fetchone()[0]
                except Exception as ex:
                    logging.error('Error encountered while trying to get MySQL database size', exc_info=ex)
                    abort(500, description="Internal Server Error")
            case 'postgresql':
                try:
                    db=get_db()
                    cursor=db.cursor()
                    cursor.execute("SELECT pg_database_size(?);", (config['database']['postgresql']['database'],))
                    db_size=cursor.fetchone()[0]
                except Exception as ex:
                    logging.error('Error encountered while trying to get PostgreSQL database size', exc_info=ex)
                    abort(500, description="Internal Server Error")
            case 'sqlite':
                db_size=os.path.getsize(os.path.join(current_app.instance_path, 'adsbportal.sqlite3'))
        
    response=jsonify(size=db_size)
    response.headers.add('Access-Control-Allow-Origin', '*')
    return response, 200

