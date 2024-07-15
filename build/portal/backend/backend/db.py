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