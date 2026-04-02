"""add live map spider overlay setting

Revision ID: a2b3c4d5e6f7
Revises: f1a2b3c4d5e6
Create Date: 2026-04-02 00:00:00.000000

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = 'a2b3c4d5e6f7'
down_revision = 'f1a2b3c4d5e6'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_spider_overlay_enabled', 'true'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_spider_overlay_enabled')
    """)


def downgrade():
    op.execute("DELETE FROM settings WHERE name = 'live_map_spider_overlay_enabled'")
