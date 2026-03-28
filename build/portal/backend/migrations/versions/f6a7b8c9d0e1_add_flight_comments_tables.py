"""add flight comments tables

Revision ID: f6a7b8c9d0e1
Revises: d3e4f5a6b7c8
Create Date: 2026-03-27 23:40:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = 'f6a7b8c9d0e1'
down_revision = 'd3e4f5a6b7c8'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'dump1090_flight_comments',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('flight_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['flight_id'], ['dump1090_flights.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_dump1090_flight_comments_flight_id'), 'dump1090_flight_comments', ['flight_id'], unique=False)
    op.create_index(op.f('ix_dump1090_flight_comments_user_id'), 'dump1090_flight_comments', ['user_id'], unique=False)
    op.create_index(op.f('ix_dump1090_flight_comments_created_at'), 'dump1090_flight_comments', ['created_at'], unique=False)

    op.create_table(
        'dump978_flight_comments',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('flight_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['flight_id'], ['dump978_flights.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_dump978_flight_comments_flight_id'), 'dump978_flight_comments', ['flight_id'], unique=False)
    op.create_index(op.f('ix_dump978_flight_comments_user_id'), 'dump978_flight_comments', ['user_id'], unique=False)
    op.create_index(op.f('ix_dump978_flight_comments_created_at'), 'dump978_flight_comments', ['created_at'], unique=False)


def downgrade():
    op.drop_index(op.f('ix_dump978_flight_comments_created_at'), table_name='dump978_flight_comments')
    op.drop_index(op.f('ix_dump978_flight_comments_user_id'), table_name='dump978_flight_comments')
    op.drop_index(op.f('ix_dump978_flight_comments_flight_id'), table_name='dump978_flight_comments')
    op.drop_table('dump978_flight_comments')

    op.drop_index(op.f('ix_dump1090_flight_comments_created_at'), table_name='dump1090_flight_comments')
    op.drop_index(op.f('ix_dump1090_flight_comments_user_id'), table_name='dump1090_flight_comments')
    op.drop_index(op.f('ix_dump1090_flight_comments_flight_id'), table_name='dump1090_flight_comments')
    op.drop_table('dump1090_flight_comments')
