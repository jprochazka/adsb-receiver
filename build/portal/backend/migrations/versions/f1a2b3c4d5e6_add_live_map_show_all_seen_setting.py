"""add live map show all seen setting

Revision ID: f1a2b3c4d5e6
Revises: e1f2a3b4c5d6
Create Date: 2026-03-28 00:00:00.000000

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = 'f1a2b3c4d5e6'
down_revision = 'e1f2a3b4c5d6'
branch_labels = None
depends_on = None


def upgrade():
    op.execute("""
        INSERT INTO settings (name, value)
        SELECT 'live_map_show_all_seen', 'true'
        WHERE NOT EXISTS (SELECT 1 FROM settings WHERE name = 'live_map_show_all_seen')
    """)


def downgrade():
    op.execute("DELETE FROM settings WHERE name = 'live_map_show_all_seen'")
