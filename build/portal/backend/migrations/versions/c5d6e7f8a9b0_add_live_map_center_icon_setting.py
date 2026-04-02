"""add live map center icon setting

Revision ID: c5d6e7f8a9b0
Revises: b3c4d5e6f7a8
Create Date: 2026-04-02 00:00:00.000000

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = 'c5d6e7f8a9b0'
down_revision = 'b3c4d5e6f7a8'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_center_icon_enabled', 'true'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_center_icon_enabled')
    """)


def downgrade():
    op.execute("DELETE FROM settings WHERE name = 'live_map_center_icon_enabled'")