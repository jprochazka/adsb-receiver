import os

import pytest

from backend.config_loader import load_portal_config


def test_load_portal_config_uses_backend_root_when_cwd_changes(tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)

    config = load_portal_config()

    assert config['database']['use'] == 'sqlite'


def test_load_portal_config_can_load_explicit_path(tmp_path):
    config_path = tmp_path / 'config.yml'
    config_path.write_text(
        "database:\n"
        "  use: sqlite\n"
        "security:\n"
        "  jwt_secret_key: test-secret\n",
        encoding='utf-8',
    )

    config = load_portal_config(config_path)

    assert config['database']['use'] == 'sqlite'
    assert config['security']['jwt_secret_key'] == 'test-secret'


def test_load_portal_config_rejects_missing_file(tmp_path):
    missing = tmp_path / 'missing.yml'

    with pytest.raises(FileNotFoundError, match=os.fspath(missing)):
        load_portal_config(missing)
