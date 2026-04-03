"""add indexes for flight query paths

Revision ID: f3c4d5e6a7b8
Revises: f0b1c2d3e4f5, f1a2b3c4d5e6, f2b6c7d8e9f0
Create Date: 2026-04-03

"""
from alembic import op


# revision identifiers, used by Alembic.
revision = 'f3c4d5e6a7b8'
down_revision = ('f0b1c2d3e4f5', 'f1a2b3c4d5e6', 'f2b6c7d8e9f0')
branch_labels = None
depends_on = None


def upgrade():
    # ADS-B: supports ORDER BY last_seen, flight and ignore_on_purge filtering.
    op.create_index(
        'ix_dump1090_flights_last_seen_flight',
        'dump1090_flights',
        ['last_seen', 'flight'],
        unique=False,
    )
    op.create_index(
        'ix_dump1090_flights_ignore_last_seen',
        'dump1090_flights',
        ['ignore_on_purge', 'last_seen'],
        unique=False,
    )

    # UAT: supports ORDER BY last_seen, flight and ignore_on_purge filtering.
    op.create_index(
        'ix_dump978_flights_last_seen_flight',
        'dump978_flights',
        ['last_seen', 'flight'],
        unique=False,
    )
    op.create_index(
        'ix_dump978_flights_ignore_last_seen',
        'dump978_flights',
        ['ignore_on_purge', 'last_seen'],
        unique=False,
    )

    # Position history endpoints filter by flight and sort by time.
    op.create_index(
        'ix_dump1090_positions_flight_time',
        'dump1090_positions',
        ['flight', 'time'],
        unique=False,
    )
    op.create_index(
        'ix_dump978_positions_flight_time',
        'dump978_positions',
        ['flight', 'time'],
        unique=False,
    )


def downgrade():
    op.drop_index('ix_dump978_positions_flight_time', table_name='dump978_positions')
    op.drop_index('ix_dump1090_positions_flight_time', table_name='dump1090_positions')
    op.drop_index('ix_dump978_flights_ignore_last_seen', table_name='dump978_flights')
    op.drop_index('ix_dump978_flights_last_seen_flight', table_name='dump978_flights')
    op.drop_index('ix_dump1090_flights_ignore_last_seen', table_name='dump1090_flights')
    op.drop_index('ix_dump1090_flights_last_seen_flight', table_name='dump1090_flights')
