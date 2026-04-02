"""add live map theoretical range settings

Revision ID: e7f8a9b0c1d2
Revises: d6e7f8a9b0c1
Create Date: 2026-04-02 00:00:00.000000

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = 'e7f8a9b0c1d2'
down_revision = 'd6e7f8a9b0c1'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_theoretical_range_enabled', 'false'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_theoretical_range_enabled')
    """)
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_theoretical_range_json', ''
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_theoretical_range_json')
    """)


def downgrade():
    op.execute("DELETE FROM settings WHERE name = 'live_map_theoretical_range_json'")
    op.execute("DELETE FROM settings WHERE name = 'live_map_theoretical_range_enabled'")