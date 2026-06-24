import logging
import os
import re
import socket
import subprocess

from flask import Blueprint, abort, jsonify, request
from flask_restx import Namespace, Resource, fields as restx_fields
from sqlalchemy import select
from backend.config_loader import get_graphs_config

graphs = Blueprint('graphs', __name__)
graphs_ns = Namespace('graphs', description='Historical RRD graph data for Chart.js')

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

_g              = get_graphs_config()
_RRD_BASE       = _g.get('rrd_base') or os.environ.get('RRD_BASE', 'instance/rrd')
_RRD_HOST       = _g.get('hostname', socket.gethostname())
_D1090_INSTANCE = _g.get('dump1090_instance', 'localhost')
_D978_INSTANCE  = _g.get('dump978_instance', 'localhost')

_D1090_DIR = f'{_RRD_BASE}/{_RRD_HOST}/dump1090-{_D1090_INSTANCE}'
_D978_DIR  = f'{_RRD_BASE}/{_RRD_HOST}/dump978-{_D978_INSTANCE}'
_SYS_DIR   = f'{_RRD_BASE}/{_RRD_HOST}'

VALID_PERIODS = {'1h', '6h', '24h', '2d', '7d', '30d'}

# ---------------------------------------------------------------------------
# Metric definitions
#
# Each entry is a list of (dataset_label, rrd_path, ds_name, consolidation_fn)
# Multiple entries sharing the same rrd_path are fetched once and split by DS.
# ---------------------------------------------------------------------------

def _spec(path, cf='AVERAGE'):
    return (path, cf)


DUMP1090_METRICS = {
    'aircraft': [
        ('total',     *_spec(f'{_D1090_DIR}/dump1090_aircraft-recent.rrd'), 'total'),
        ('positions', *_spec(f'{_D1090_DIR}/dump1090_aircraft-recent.rrd'), 'positions'),
        ('mlat',      *_spec(f'{_D1090_DIR}/dump1090_mlat-recent.rrd'), 'value'),
    ],
    'message-rate': [
        ('messages',       *_spec(f'{_D1090_DIR}/dump1090_messages-local_accepted.rrd'), 'value'),
        ('strong_signals', *_spec(f'{_D1090_DIR}/dump1090_messages-strong_signals.rrd'), 'value'),
        ('positions',      *_spec(f'{_D1090_DIR}/dump1090_messages-positions.rrd'), 'value'),
    ],
    'cpu': [
        ('demod',      *_spec(f'{_D1090_DIR}/dump1090_cpu-demod.rrd'), 'value'),
        ('reader',     *_spec(f'{_D1090_DIR}/dump1090_cpu-reader.rrd'), 'value'),
        ('background', *_spec(f'{_D1090_DIR}/dump1090_cpu-background.rrd'), 'value'),
    ],
    'tracks': [
        ('all',            *_spec(f'{_D1090_DIR}/dump1090_tracks-all.rrd'), 'value'),
        ('single_message', *_spec(f'{_D1090_DIR}/dump1090_tracks-single_message.rrd'), 'value'),
    ],
    'range': [
        ('max_range', *_spec(f'{_D1090_DIR}/dump1090_range-max_range.rrd', 'MAX'), 'value'),
    ],
    'signal': [
        ('signal',      *_spec(f'{_D1090_DIR}/dump1090_dbfs-signal.rrd'), 'value'),
        ('peak_signal', *_spec(f'{_D1090_DIR}/dump1090_dbfs-peak_signal.rrd'), 'value'),
        ('min_signal',  *_spec(f'{_D1090_DIR}/dump1090_dbfs-min_signal.rrd'), 'value'),
        ('noise',       *_spec(f'{_D1090_DIR}/dump1090_dbfs-noise.rrd'), 'value'),
    ],
    'positions': [
        ('positions', *_spec(f'{_D1090_DIR}/dump1090_messages-positions.rrd'), 'value'),
    ],
    'strong-signals': [
        ('strong', *_spec(f'{_D1090_DIR}/dump1090_messages-strong_signals.rrd'), 'value'),
        ('total',  *_spec(f'{_D1090_DIR}/dump1090_messages-local_accepted.rrd'), 'value'),
    ],
    'df-types': [
        ('df17',  *_spec(f'{_D1090_DIR}/dump1090_messages-local_accepted_17.rrd'), 'value'),
        ('df18',  *_spec(f'{_D1090_DIR}/dump1090_messages-local_accepted_18.rrd'), 'value'),
        ('df11',  *_spec(f'{_D1090_DIR}/dump1090_messages-local_accepted_11.rrd'), 'value'),
        ('df4',   *_spec(f'{_D1090_DIR}/dump1090_messages-local_accepted_4.rrd'), 'value'),
        ('df5',   *_spec(f'{_D1090_DIR}/dump1090_messages-local_accepted_5.rrd'), 'value'),
        ('df20',  *_spec(f'{_D1090_DIR}/dump1090_messages-local_accepted_20.rrd'), 'value'),
        ('df21',  *_spec(f'{_D1090_DIR}/dump1090_messages-local_accepted_21.rrd'), 'value'),
        ('total', *_spec(f'{_D1090_DIR}/dump1090_messages-local_accepted.rrd'), 'value'),
    ],
    'remote-rate': [
        ('messages',  *_spec(f'{_D1090_DIR}/dump1090_messages-remote_accepted.rrd'), 'value'),
        ('positions', *_spec(f'{_D1090_DIR}/dump1090_messages-positions.rrd'), 'value'),
    ],
}

DUMP978_METRICS = {
    'aircraft': [
        ('total',         *_spec(f'{_D978_DIR}/dump978_aircraft-recent.rrd'), 'total'),
        ('positions',     *_spec(f'{_D978_DIR}/dump978_aircraft-recent.rrd'), 'positions'),
        ('with_callsign', *_spec(f'{_D978_DIR}/dump978_aircraft-recent.rrd'), 'with_callsign'),
    ],
    'signal': [
        ('signal', *_spec(f'{_D978_DIR}/dump978_dbfs-signal.rrd'), 'value'),
    ],
    'messages': [
        ('messages', *_spec(f'{_D978_DIR}/dump978_messages-messages.rrd'), 'value'),
    ],
    'range': [
        ('max_range', *_spec(f'{_D978_DIR}/dump978_range-max_range.rrd', 'MAX'), 'value'),
    ],
    'altitude': [
        ('altitude', *_spec(f'{_D978_DIR}/dump978_altitude-average.rrd'), 'value'),
    ],
}

SYSTEM_METRICS = {
    'cpu': [
        ('idle',      *_spec(f'{_SYS_DIR}/aggregation-cpu-average/cpu-idle.rrd'), 'value'),
        ('interrupt', *_spec(f'{_SYS_DIR}/aggregation-cpu-average/cpu-interrupt.rrd'), 'value'),
        ('nice',      *_spec(f'{_SYS_DIR}/aggregation-cpu-average/cpu-nice.rrd'), 'value'),
        ('softirq',   *_spec(f'{_SYS_DIR}/aggregation-cpu-average/cpu-softirq.rrd'), 'value'),
        ('steal',     *_spec(f'{_SYS_DIR}/aggregation-cpu-average/cpu-steal.rrd'), 'value'),
        ('system',    *_spec(f'{_SYS_DIR}/aggregation-cpu-average/cpu-system.rrd'), 'value'),
        ('user',      *_spec(f'{_SYS_DIR}/aggregation-cpu-average/cpu-user.rrd'), 'value'),
        ('wait',      *_spec(f'{_SYS_DIR}/aggregation-cpu-average/cpu-wait.rrd'), 'value'),
    ],
    'disk-usage': [
        ('used',     *_spec(f'{_SYS_DIR}/df-root/df_complex-used.rrd'), 'value'),
        ('reserved', *_spec(f'{_SYS_DIR}/df-root/df_complex-reserved.rrd'), 'value'),
        ('free',     *_spec(f'{_SYS_DIR}/df-root/df_complex-free.rrd'), 'value'),
    ],
    'disk-io-iops': [
        ('read',  *_spec(f'{_SYS_DIR}/disk-mmcblk0/disk_ops.rrd'), 'read'),
        ('write', *_spec(f'{_SYS_DIR}/disk-mmcblk0/disk_ops.rrd'), 'write'),
    ],
    'disk-io-bandwidth': [
        ('read',  *_spec(f'{_SYS_DIR}/disk-mmcblk0/disk_octets.rrd'), 'read'),
        ('write', *_spec(f'{_SYS_DIR}/disk-mmcblk0/disk_octets.rrd'), 'write'),
    ],
    'memory': [
        ('buffered', *_spec(f'{_SYS_DIR}/memory/memory-buffered.rrd'), 'value'),
        ('cached',   *_spec(f'{_SYS_DIR}/memory/memory-cached.rrd'), 'value'),
        ('free',     *_spec(f'{_SYS_DIR}/memory/memory-free.rrd'), 'value'),
        ('used',     *_spec(f'{_SYS_DIR}/memory/memory-used.rrd'), 'value'),
    ],
    'temperature': [
        ('temperature', *_spec(f'{_SYS_DIR}/thermal-thermal_zone0/temperature.rrd', 'MAX'), 'value'),
    ],
}

# ---------------------------------------------------------------------------
# RRD fetch helpers
# ---------------------------------------------------------------------------

def _fetch_rrd(
    rrd_path: str,
    ds_name: str,
    cf: str,
    period: str,
    start: int | None = None,
    end: int | None = None,
    step: int | None = None,
) -> dict:
    """
    Run ``rrdtool fetch`` and return a {unix_timestamp: float|None} dict for
    the requested data-source column. Returns an empty dict on any error.
    """
    if not os.path.isfile(rrd_path):
        # File absent means collection is disabled for this metric — not an error.
        return {}

    cmd = ['rrdtool', 'fetch', rrd_path, cf]
    if start is not None and end is not None:
        cmd.extend(['--start', str(start), '--end', str(end)])
    else:
        cmd.extend(['--start', f'end-{period}', '--end', 'now'])

    if step is not None:
        cmd.extend(['--resolution', str(step)])

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)

    if result.returncode != 0:
        logging.error('rrdtool fetch failed for %s: %s', rrd_path, result.stderr.strip())
        return {}

    lines = [l for l in result.stdout.splitlines() if l.strip()]
    if len(lines) < 2:
        return {}

    # First non-empty line is the space-separated DS name header.
    ds_names = lines[0].split()
    try:
        col_idx = ds_names.index(ds_name)
    except ValueError:
        logging.error('DS "%s" not found in %s. Available: %s', ds_name, rrd_path, ds_names)
        return {}

    data = {}
    for line in lines[1:]:
        m = re.match(r'^(\d+):\s+(.+)$', line)
        if not m:
            continue
        ts = int(m.group(1))
        values = m.group(2).split()
        if col_idx < len(values):
            v = values[col_idx]
            data[ts] = None if v.lower() in ('nan', '-nan', 'inf', '-inf') else float(v)

    return data


def _build_chart_response(
    series: list,
    period: str,
    start: int | None = None,
    end: int | None = None,
    step: int | None = None,
) -> dict:
    """
    Fetch all series and merge into a Chart.js-compatible response.

    ``series`` is a list of (label, rrd_path, cf, ds_name) tuples.
    Timestamps are aligned as the union of all fetched timestamp sets.
    Missing values for a given timestamp are returned as ``null``.
    """
    all_timestamps: set = set()
    fetched_series = []

    for label, rrd_path, cf, ds_name in series:
        ts_map = _fetch_rrd(rrd_path, ds_name, cf, period, start=start, end=end, step=step)
        all_timestamps.update(ts_map.keys())
        fetched_series.append((label, ts_map))

    sorted_timestamps = sorted(all_timestamps)

    return {
        'period': period,
        'start': start,
        'end': end,
        'step': step,
        'labels': sorted_timestamps,
        'datasets': [
            {
                'label': label,
                'data': [ts_map.get(ts) for ts in sorted_timestamps]
            }
            for label, ts_map in fetched_series
        ]
    }


def _metric_to_series(metric_list: list) -> list:
    """Convert a metric definition list into (label, path, cf, ds) tuples."""
    return [(label, rrd_path, cf, ds_name) for label, rrd_path, cf, ds_name in metric_list]


def _parse_window_query() -> tuple[str, int | None, int | None, int | None]:
    """
    Parse graph query range parameters.

    Supported query styles:
      - period-based: ?period=24h
      - exact window: ?start=<unix>&end=<unix>[&step=<seconds>]
    """
    period = request.args.get('period', '24h')
    start_arg = request.args.get('start')
    end_arg = request.args.get('end')
    step_arg = request.args.get('step')

    start = None
    end = None
    step = None

    if start_arg is not None or end_arg is not None:
        if start_arg is None or end_arg is None:
            abort(400, 'Both start and end must be provided for exact range queries')

        try:
            start = int(start_arg)
            end = int(end_arg)
        except ValueError:
            abort(400, 'start/end must be unix timestamps (integer seconds)')

        if end <= start:
            abort(400, 'end must be greater than start')
    else:
        if period not in VALID_PERIODS:
            abort(400, f'Invalid period. Valid values: {", ".join(sorted(VALID_PERIODS))}')

    if step_arg is not None:
        try:
            step = int(step_arg)
        except ValueError:
            abort(400, 'step must be an integer number of seconds')

        if step <= 0:
            abort(400, 'step must be greater than 0')

    return period, start, end, step


def _get_network_interface() -> str:
    """Read the configured network interface from the portal settings DB."""
    from backend.models import db, Setting
    row = db.session.execute(
        select(Setting).filter_by(name='graphs_network_interface')
    ).scalar_one_or_none()
    return row.value if row else 'eth0'

# ---------------------------------------------------------------------------
# API models
# ---------------------------------------------------------------------------

dataset_model = graphs_ns.model('Dataset', {
    'label': restx_fields.String(description='Dataset name'),
    'data':  restx_fields.List(restx_fields.Float(allow_null=True), description='Data values (null for gaps)')
})

graph_response_model = graphs_ns.model('GraphResponse', {
    'period':   restx_fields.String(description='Requested time period'),
    'labels':   restx_fields.List(restx_fields.Integer(description='Unix timestamp')),
    'datasets': restx_fields.List(restx_fields.Nested(dataset_model))
})

# ---------------------------------------------------------------------------
# Routes — dump1090
# ---------------------------------------------------------------------------

@graphs_ns.route('/dump1090/<string:metric>')
@graphs_ns.param('metric', 'Chart metric: aircraft | message-rate | cpu | tracks | range | signal | positions | strong-signals | df-types | remote-rate')
class Dump1090GraphResource(Resource):
    @graphs_ns.param('period', 'Time period: 1h | 6h | 24h | 2d | 7d | 30d', _in='query')
    @graphs_ns.response(200, 'Success', graph_response_model)
    @graphs_ns.response(400, 'Invalid period')
    @graphs_ns.response(404, 'Unknown metric')
    @graphs_ns.doc('get_dump1090_graph')
    def get(self, metric):
        """Get dump1090 chart data from RRD"""
        if metric not in DUMP1090_METRICS:
            abort(404, f'Unknown dump1090 metric: {metric}')
        period, start, end, step = _parse_window_query()
        return jsonify(_build_chart_response(_metric_to_series(DUMP1090_METRICS[metric]), period, start, end, step))


# ---------------------------------------------------------------------------
# Routes — dump978
# ---------------------------------------------------------------------------

@graphs_ns.route('/dump978/<string:metric>')
@graphs_ns.param('metric', 'Chart metric: aircraft | signal | messages | range | altitude')
class Dump978GraphResource(Resource):
    @graphs_ns.param('period', 'Time period: 1h | 6h | 24h | 2d | 7d | 30d', _in='query')
    @graphs_ns.response(200, 'Success', graph_response_model)
    @graphs_ns.response(400, 'Invalid period')
    @graphs_ns.response(404, 'Unknown metric')
    @graphs_ns.doc('get_dump978_graph')
    def get(self, metric):
        """Get dump978 chart data from RRD"""
        if metric not in DUMP978_METRICS:
            abort(404, f'Unknown dump978 metric: {metric}')
        period, start, end, step = _parse_window_query()
        return jsonify(_build_chart_response(_metric_to_series(DUMP978_METRICS[metric]), period, start, end, step))


# ---------------------------------------------------------------------------
# Routes — devices
# ---------------------------------------------------------------------------

@graphs_ns.route('/devices/<string:metric>')
@graphs_ns.param('metric', 'Chart metric: cpu | disk-usage | disk-io-iops | disk-io-bandwidth | network | memory | temperature')
class DevicesGraphResource(Resource):
    @graphs_ns.param('period', 'Time period: 1h | 6h | 24h | 2d | 7d | 30d', _in='query')
    @graphs_ns.response(200, 'Success', graph_response_model)
    @graphs_ns.response(400, 'Invalid period')
    @graphs_ns.response(404, 'Unknown metric')
    @graphs_ns.response(503, 'RRD data not available')
    @graphs_ns.doc('get_devices_graph')
    def get(self, metric):
        """Get devices chart data from RRD"""
        period, start, end, step = _parse_window_query()

        if metric == 'network':
            iface = _get_network_interface()
            rrd_path = f'{_SYS_DIR}/interface-{iface}/if_octets.rrd'
            if not os.path.isfile(rrd_path):
                return (
                    {'error': f'RRD file not found for network interface "{iface}". '
                              'Verify the interface name in settings and that data collection is running.'},
                    503,
                )
            series = [
                ('rx', rrd_path, 'AVERAGE', 'rx'),
                ('tx', rrd_path, 'AVERAGE', 'tx'),
            ]
        elif metric in SYSTEM_METRICS:
            series = _metric_to_series(SYSTEM_METRICS[metric])
            missing = [rrd_path for _, rrd_path, _, _ in series if not os.path.isfile(rrd_path)]
            if len(missing) == len(series):
                return (
                    {'error': f'RRD files not found for metric "{metric}". '
                              'Data collection may not be running yet.'},
                    503,
                )
        else:
            abort(404, f'Unknown devices metric: {metric}')

        return jsonify(_build_chart_response(series, period, start, end, step))
