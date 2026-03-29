"""add live map custom presets setting

Revision ID: d4e5f6a7b8c9
Revises: c4d5e6f7a8b9
Create Date: 2026-03-28 00:00:00.000000

"""
from alembic import op
import json
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'd4e5f6a7b8c9'
down_revision = 'c4d5e6f7a8b9'
branch_labels = None
depends_on = None


def upgrade():
    default_custom_presets = [
        {"label": "Home", "refreshMs": 2500, "centerLat": 39, "centerLon": -95, "zoom": 7, "trailPoints": 40},
        {"label": "Summer", "refreshMs": 5000, "centerLat": 20, "centerLon": 0, "zoom": 3, "trailPoints": 20},
        {"label": "Winter", "refreshMs": 7000, "centerLat": 50, "centerLon": 10, "zoom": 4, "trailPoints": 15},
    ]
    encoded = json.dumps(default_custom_presets, separators=(",", ":"))

    op.execute(sa.text("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_custom_presets',
               :encoded
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_custom_presets')
    """).bindparams(encoded=encoded))


def downgrade():
    op.execute("DELETE FROM settings WHERE name = 'live_map_custom_presets'")
