from pathlib import Path

import yaml

BACKEND_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG_PATH = BACKEND_ROOT / 'config.yml'


def load_portal_config(config_path=None):
    """Load portal config.yml from a stable path, independent of process cwd."""
    path = Path(config_path) if config_path is not None else DEFAULT_CONFIG_PATH
    if not path.exists():
        raise FileNotFoundError(path)

    with path.open(encoding='utf-8') as f:
        return yaml.safe_load(f) or {}


def get_database_config(config=None):
    return (config or load_portal_config()).get('database', {})


def get_security_config(config=None):
    return (config or load_portal_config()).get('security', {})


def get_graphs_config(config=None):
    return (config or load_portal_config()).get('graphs', {})


def get_rrd_writer_config(config=None):
    return (config or load_portal_config()).get('rrd_writer', {})


def get_acars_config(config=None):
    return (config or load_portal_config()).get('acars', {})
