import pytest
import sqlite3

from backend.db import get_db

def test_get_close_db(app):
    with app.app_context():
        db=get_db()
        assert db is get_db()

    with pytest.raises(sqlite3.ProgrammingError) as e:
        db.execute('SELECT 1')

    assert 'closed' in str(e.value)

def test_init_db_command(runner, monkeypatch):
    class Recorder(object):
        called = False

    def fake_init_db():
        Recorder.called = True

    monkeypatch.setattr('backend.db.init_db', fake_init_db)
    result = runner.invoke(args=['init-db'])
    assert 'initialized' in result.output
    assert Recorder.called