import logging
import psutil

from flask import  abort, Blueprint
from backend.db import get_db


monitors = Blueprint('monitors', __name__)

@monitors.route("/api/monitors/cpu", methods=["POST"])
def cpu():
    memory = psutil.virtual_memory()
    cpu_data = {
        'cpu_percent': psutil.cpu_percent(1),
        'cpu_count': psutil.cpu_count(),
        'cpu_freq': psutil.cpu_freq(),
        'cpu_mem_total': memory.total,
        'cpu_mem_avail': memory.available,
        'cpu_mem_used': memory.used,
        'cpu_mem_free': memory.free,
        'sensor_temperatures': psutil.sensors_temperatures()['cpu-thermal'][0].current
    }
    return cpu_data

@monitors.route("/api/monitors/disk", methods=["POST"])
def disk():
    disk = psutil.disk_usage('/')
    cpu_data = {
        'disk_usage_total': disk.total,
        'disk_usage_used': disk.used,
        'disk_usage_free': disk.free,
        'disk_usage_percent': disk.percent,
    }
    return cpu_data

@monitors.route("/api/monitors/database", methods=["POST"])
def disk():
    try:
        db=get_db()
        cursor=db.cursor()
        cursor.execute("SELECT table_schema AS name, ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS size_in_mb FROM information_schema.tables ROUP BY table_schema;")
        count=cursor.fetchone()[0]
    except Exception as ex:
        logging.error('Error encountered while trying to get flight count', exc_info=ex)
        abort(500, description="Internal Server Error")
    return