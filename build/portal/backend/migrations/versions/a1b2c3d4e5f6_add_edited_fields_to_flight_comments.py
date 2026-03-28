"""add edited fields to flight comments

Revision ID: a1b2c3d4e5f6
Revises: f6a7b8c9d0e1
Create Date: 2026-03-27 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'a1b2c3d4e5f6'
down_revision = 'f6a7b8c9d0e1'
branch_labels = None
depends_on = None


def upgrade():
    with op.batch_alter_table('dump1090_flight_comments', schema=None) as batch_op:
        batch_op.add_column(sa.Column('edited', sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column('edited_at', sa.DateTime(), nullable=True))

    with op.batch_alter_table('dump978_flight_comments', schema=None) as batch_op:
        batch_op.add_column(sa.Column('edited', sa.Boolean(), nullable=False, server_default=sa.false()))
        batch_op.add_column(sa.Column('edited_at', sa.DateTime(), nullable=True))


def downgrade():
    with op.batch_alter_table('dump978_flight_comments', schema=None) as batch_op:
        batch_op.drop_column('edited_at')
        batch_op.drop_column('edited')

    with op.batch_alter_table('dump1090_flight_comments', schema=None) as batch_op:
        batch_op.drop_column('edited_at')
        batch_op.drop_column('edited')