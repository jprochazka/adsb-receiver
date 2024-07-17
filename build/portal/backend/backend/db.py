import click
import MySQLdb
import os
import psycopg2
import sqlite3
import yaml

from flask import current_app, g

config=yaml.safe_load(open("config.yml"))

def init_app(app):
    app.teardown_appcontext(close_db)
    app.cli.add_command(init_db_command)

def get_db():
    if 'db' not in g:
        match config['database']['use'].lower():
            case 'mysql':
                g.db = MySQLdb.connect(
                    host=config['database']['mysql']['host'],
                    user=config['database']['mysql']['user'],
                    password=config['database']['mysql']['password'],
                    database=config['database']['mysql']['database']
                )
            case 'postgresql':
                g.db = psycopg2.connect(
                    host=config['database']['mysql']['host'],
                    user=config['database']['mysql']['user'],
                    password=config['database']['mysql']['password'],
                    database=config['database']['mysql']['database']
                )
            case 'sqlite':
                g.db = sqlite3.connect(os.path.join(current_app.instance_path, 'adsbportal.sqlite3'))
    
    return g.db

def close_db(e=None):
    db = g.pop('db', None)

    if db is not None:
        db.close()

def init_db():
    db = get_db()

    sql_file = os.path.join("schemas", f"{config['database']['use'].lower()}.sql")
    with current_app.open_resource(sql_file, "r") as f:
        db.executescript(f.read())

@click.command('init-db')
def init_db_command():
    init_db()
    click.echo('Database initialized')