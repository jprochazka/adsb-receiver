"""add live map distance ring compass lines setting

Revision ID: d6e7f8a9b0c1
Revises: c5d6e7f8a9b0
Create Date: 2026-04-02 00:00:00.000000

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = 'd6e7f8a9b0c1'
down_revision = 'c5d6e7f8a9b0'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_distance_ring_compass_lines_enabled', 'true'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_distance_ring_compass_lines_enabled')
    """)


def downgrade():
    op.execute("DELETE FROM settings WHERE name = 'live_map_distance_ring_compass_lines_enabled'")
