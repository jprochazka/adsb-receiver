import click
import MySQLdb
import psycopg2
import sqlite3
import yaml

config=yaml.safe_load(open("config.yml"))


def create_connection():
    match config['database']['use'].lower():
        case 'mysql':
            return MySQLdb.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
        case 'postgresql':
            return psycopg2.connect(
                host=config['database']['mysql']['host'],
                user=config['database']['mysql']['user'],
                password=config['database']['mysql']['password'],
                database=config['database']['mysql']['database']
            )
        case 'sqlite':
            return sqlite3.connect(config['database']['sqlite']['path'])


def init_app(app):
    app.cli.add_command(init_db_command)

def init_db():
    connection = create_connection()
    cursor=connection.cursor()

    sql_file = open(f"./backend/schemas/{config['database']['use'].lower()}.sql", "r")
    sql_script = sql_file.read()
    cursor.executescript(sql_script)

    connection.commit()
    connection.close()

@click.command('init-db')
def init_db_command():
    init_db()
    click.echo('Database inititalized')