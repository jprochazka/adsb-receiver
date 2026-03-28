"""add ignore_on_purge to flights

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f6
Create Date: 2026-03-28 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'b2c3d4e5f6a7'
down_revision = 'a1b2c3d4e5f6'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('dump1090_flights', schema=None) as batch_op:
        batch_op.add_column(sa.Column('ignore_on_purge', sa.Boolean(), nullable=False, server_default=sa.false()))

    with op.batch_alter_table('dump978_flights', schema=None) as batch_op:
        batch_op.add_column(sa.Column('ignore_on_purge', sa.Boolean(), nullable=False, server_default=sa.false()))


def downgrade():
    with op.batch_alter_table('dump978_flights', schema=None) as batch_op:
        batch_op.drop_column('ignore_on_purge')

    with op.batch_alter_table('dump1090_flights', schema=None) as batch_op:
        batch_op.drop_column('ignore_on_purge')