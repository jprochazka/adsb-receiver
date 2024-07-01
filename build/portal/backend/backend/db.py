import sqlite3
import yaml

import click
from flask import current_app, g

config=yaml.safe_load(open("config.yml"))

# SQLITE

def get_sqlite_db():
    if 'db' not in g:
        g.db = sqlite3.connect(
            config['database']['sqlite']['path'],
            detect_types=sqlite3.PARSE_DECLTYPES
        )
        g.db.row_factory = sqlite3.Row

    return g.db

def close_sqlite_db(e=None):
    db = g.pop('db', None)

    if db is not None:
        db.close()

def init_sqlite_db():
    db = get_sqlite_db()

    with current_app.open_resource('schemas/sqlite.sql') as f:
        db.executescript(f.read().decode('utf8'))

@click.command('init-sqlite-db')
def init_db_command():
    init_sqlite_db()
    click.echo('Database initialized.')

def init_app(app):
    match config['database']['use'].lower():
        case 'sqlite':
            app.teardown_appcontext(close_sqlite_db)
            
    app.cli.add_command(init_db_command)