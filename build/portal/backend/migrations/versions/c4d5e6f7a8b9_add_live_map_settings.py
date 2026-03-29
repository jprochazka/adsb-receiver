"""add live map settings

Revision ID: c4d5e6f7a8b9
Revises: b2c3d4e5f6a7
Create Date: 2026-03-28 00:00:00.000000

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = 'c4d5e6f7a8b9'
down_revision = 'b2c3d4e5f6a7'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_enabled', 'true'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_enabled')
    """)
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_refresh_ms', '5000'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_refresh_ms')
    """)
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_center_lat', '20'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_center_lat')
    """)
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_center_lon', '0'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_center_lon')
    """)
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_default_zoom', '3'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_default_zoom')
    """)
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_trail_points', '20'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_trail_points')
    """)


def downgrade():
    op.execute("DELETE FROM settings WHERE name = 'live_map_trail_points'")
    op.execute("DELETE FROM settings WHERE name = 'live_map_default_zoom'")
    op.execute("DELETE FROM settings WHERE name = 'live_map_center_lon'")
    op.execute("DELETE FROM settings WHERE name = 'live_map_center_lat'")
    op.execute("DELETE FROM settings WHERE name = 'live_map_refresh_ms'")
    op.execute("DELETE FROM settings WHERE name = 'live_map_enabled'")
