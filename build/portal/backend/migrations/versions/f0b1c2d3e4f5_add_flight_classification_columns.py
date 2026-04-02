"""add flight classification columns

Revision ID: f0b1c2d3e4f5
Revises: e7f8a9b0c1d2
Create Date: 2026-04-02 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f0b1c2d3e4f5'
down_revision = 'e7f8a9b0c1d2'
branch_labels = None
depends_on = None


def upgrade():
    op.add_column('dump1090_flights', sa.Column('emitter_category', sa.String(length=4), nullable=True))
    op.add_column('dump1090_flights', sa.Column('message_type', sa.String(length=32), nullable=True))
    op.add_column('dump1090_flights', sa.Column('aircraft_class', sa.String(length=32), nullable=False, server_default='unknown'))

    op.add_column('dump978_flights', sa.Column('emitter_category', sa.String(length=4), nullable=True))
    op.add_column('dump978_flights', sa.Column('message_type', sa.String(length=32), nullable=True))
    op.add_column('dump978_flights', sa.Column('aircraft_class', sa.String(length=32), nullable=False, server_default='unknown'))


def downgrade():
    op.drop_column('dump978_flights', 'aircraft_class')
    op.drop_column('dump978_flights', 'message_type')
    op.drop_column('dump978_flights', 'emitter_category')

    op.drop_column('dump1090_flights', 'aircraft_class')
    op.drop_column('dump1090_flights', 'message_type')
    op.drop_column('dump1090_flights', 'emitter_category')
