"""add live map feed URL settings

Revision ID: e1f2a3b4c5d6
Revises: d4e5f6a7b8c9
Create Date: 2026-03-28 00:00:00.000000

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = 'e1f2a3b4c5d6'
down_revision = 'd4e5f6a7b8c9'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_json_url', 'http://127.0.0.1/dump1090/data/aircraft.json'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_json_url')
    """)
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_json_url_dump978', 'http://127.0.0.1/dump978/data/aircraft.json'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_json_url_dump978')
    """)


def downgrade():
    op.execute("DELETE FROM settings WHERE name = 'live_map_json_url_dump978'")
    op.execute("DELETE FROM settings WHERE name = 'live_map_json_url'")
