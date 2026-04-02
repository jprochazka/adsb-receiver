"""add live map distance ring settings

Revision ID: b3c4d5e6f7a8
Revises: a2b3c4d5e6f7
Create Date: 2026-04-02 00:00:00.000000

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = 'b3c4d5e6f7a8'
down_revision = 'a2b3c4d5e6f7'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_distance_rings_enabled', 'false'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_distance_rings_enabled')
    """)
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_distance_ring_count', '4'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_distance_ring_count')
    """)
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_distance_ring_interval_miles', '25'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_distance_ring_interval_miles')
    """)


def downgrade():
    op.execute("DELETE FROM settings WHERE name = 'live_map_distance_ring_interval_miles'")
    op.execute("DELETE FROM settings WHERE name = 'live_map_distance_ring_count'")
    op.execute("DELETE FROM settings WHERE name = 'live_map_distance_rings_enabled'")
