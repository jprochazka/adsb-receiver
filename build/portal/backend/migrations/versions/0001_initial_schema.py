"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-04-03 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0001'
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    # ---- standalone tables ----
    op.create_table('blog_posts',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('date', sa.String(length=16), nullable=False),
        sa.Column('author', sa.String(length=100), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('visible', sa.Boolean(), nullable=False, default=True),
        sa.Column('tags', sa.Text(), nullable=True),
        sa.Column('category', sa.String(length=100), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )

    op.create_table('dump1090_aircraft',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('icao', sa.String(length=8), nullable=False),
        sa.Column('first_seen', sa.String(length=32), nullable=False),
        sa.Column('last_seen', sa.String(length=32), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('dump1090_aircraft') as batch_op:
        batch_op.create_index('ix_dump1090_aircraft_icao', ['icao'], unique=False)

    op.create_table('dump978_aircraft',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('icao', sa.String(length=8), nullable=False),
        sa.Column('first_seen', sa.String(length=32), nullable=False),
        sa.Column('last_seen', sa.String(length=32), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('dump978_aircraft') as batch_op:
        batch_op.create_index('ix_dump978_aircraft_icao', ['icao'], unique=False)

    op.create_table('links',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('address', sa.String(length=512), nullable=False),
        sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
        sa.PrimaryKeyConstraint('id')
    )

    op.create_table('opensky_aircraft',
        sa.Column('icao24', sa.String(length=8), nullable=False),
        sa.Column('aircraft_class', sa.String(length=32), nullable=False),
        sa.Column('confidence', sa.String(length=8), nullable=False),
        sa.PrimaryKeyConstraint('icao24')
    )

    op.create_table('settings',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('value', sa.Text(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('name')
    )

    op.create_table('users',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('password', sa.String(length=255), nullable=True),
        sa.Column('administrator', sa.Integer(), nullable=True),
        sa.Column('role', sa.String(length=20), nullable=True),
        sa.Column('locked', sa.Boolean(), nullable=False, server_default='0'),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('email')
    )

    # ---- tables with foreign keys to standalone tables ----
    op.create_table('notifications',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('flight', sa.String(length=20), nullable=False),
        sa.ForeignKeyConstraint(
            ['user_id'], ['users.id'],
            name='fk_notifications_user_id_users', ondelete='CASCADE'
        ),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id', 'flight', name='uq_notifications_user_flight')
    )
    with op.batch_alter_table('notifications') as batch_op:
        batch_op.create_index('ix_notifications_user_id', ['user_id'], unique=False)

    op.create_table('blog_comments',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('blog_post_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('parent_comment_id', sa.Integer(), nullable=True),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('edited', sa.Boolean(), nullable=False, server_default='0'),
        sa.Column('edited_at', sa.DateTime(), nullable=True),
        sa.Column('deleted', sa.Boolean(), nullable=False, server_default='0'),
        sa.Column('deleted_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['blog_post_id'], ['blog_posts.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.ForeignKeyConstraint(['parent_comment_id'], ['blog_comments.id']),
        sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('blog_comments') as batch_op:
        batch_op.create_index('ix_blog_comments_blog_post_id', ['blog_post_id'], unique=False)
        batch_op.create_index('ix_blog_comments_user_id', ['user_id'], unique=False)
        batch_op.create_index('ix_blog_comments_parent_comment_id', ['parent_comment_id'], unique=False)
        batch_op.create_index('ix_blog_comments_created_at', ['created_at'], unique=False)

    op.create_table('dump1090_flights',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('aircraft', sa.Integer(), nullable=False),
        sa.Column('flight', sa.String(length=20), nullable=False),
        sa.Column('first_seen', sa.String(length=32), nullable=False),
        sa.Column('last_seen', sa.String(length=32), nullable=True),
        sa.Column('emitter_category', sa.String(length=4), nullable=True),
        sa.Column('message_type', sa.String(length=32), nullable=True),
        sa.Column('aircraft_class', sa.String(length=32), nullable=False, server_default='unknown'),
        sa.Column('ignore_on_purge', sa.Boolean(), nullable=False, server_default=sa.text('0')),
        sa.ForeignKeyConstraint(['aircraft'], ['dump1090_aircraft.id']),
        sa.PrimaryKeyConstraint('id')
    )

    op.create_table('dump978_flights',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('aircraft', sa.Integer(), nullable=False),
        sa.Column('flight', sa.String(length=20), nullable=False),
        sa.Column('first_seen', sa.String(length=32), nullable=False),
        sa.Column('last_seen', sa.String(length=32), nullable=True),
        sa.Column('emitter_category', sa.String(length=4), nullable=True),
        sa.Column('message_type', sa.String(length=32), nullable=True),
        sa.Column('aircraft_class', sa.String(length=32), nullable=False, server_default='unknown'),
        sa.Column('ignore_on_purge', sa.Boolean(), nullable=False, server_default=sa.text('0')),
        sa.ForeignKeyConstraint(['aircraft'], ['dump978_aircraft.id']),
        sa.PrimaryKeyConstraint('id')
    )

    # ---- position tables ----
    op.create_table('dump1090_positions',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('flight', sa.Integer(), nullable=False),
        sa.Column('aircraft', sa.Integer(), nullable=False),
        sa.Column('time', sa.String(length=32), nullable=False),
        sa.Column('message', sa.Integer(), nullable=False),
        sa.Column('squawk', sa.Integer(), nullable=True),
        sa.Column('latitude', sa.Float(), nullable=False),
        sa.Column('longitude', sa.Float(), nullable=False),
        sa.Column('track', sa.Integer(), nullable=False),
        sa.Column('altitude', sa.Integer(), nullable=False),
        sa.Column('vertical_rate', sa.Integer(), nullable=False),
        sa.Column('speed', sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(['aircraft'], ['dump1090_aircraft.id']),
        sa.ForeignKeyConstraint(['flight'], ['dump1090_flights.id']),
        sa.PrimaryKeyConstraint('id')
    )

    op.create_table('dump978_positions',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('flight', sa.Integer(), nullable=True),
        sa.Column('aircraft', sa.Integer(), nullable=False),
        sa.Column('time', sa.String(length=32), nullable=False),
        sa.Column('message', sa.Integer(), nullable=True),
        sa.Column('squawk', sa.Integer(), nullable=True),
        sa.Column('latitude', sa.Float(), nullable=False),
        sa.Column('longitude', sa.Float(), nullable=False),
        sa.Column('track', sa.Integer(), nullable=False),
        sa.Column('altitude', sa.Integer(), nullable=False),
        sa.Column('vertical_rate', sa.Integer(), nullable=False),
        sa.Column('speed', sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(['aircraft'], ['dump978_aircraft.id']),
        sa.ForeignKeyConstraint(['flight'], ['dump978_flights.id']),
        sa.PrimaryKeyConstraint('id')
    )

    # ---- flight comment tables ----
    op.create_table('dump1090_flight_comments',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('flight_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('edited', sa.Boolean(), nullable=False, server_default='0'),
        sa.Column('edited_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['flight_id'], ['dump1090_flights.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('dump1090_flight_comments') as batch_op:
        batch_op.create_index('ix_dump1090_flight_comments_flight_id', ['flight_id'], unique=False)
        batch_op.create_index('ix_dump1090_flight_comments_user_id', ['user_id'], unique=False)
        batch_op.create_index('ix_dump1090_flight_comments_created_at', ['created_at'], unique=False)

    op.create_table('dump978_flight_comments',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('flight_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('content', sa.Text(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('edited', sa.Boolean(), nullable=False, server_default='0'),
        sa.Column('edited_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['flight_id'], ['dump978_flights.id']),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id')
    )
    with op.batch_alter_table('dump978_flight_comments') as batch_op:
        batch_op.create_index('ix_dump978_flight_comments_flight_id', ['flight_id'], unique=False)
        batch_op.create_index('ix_dump978_flight_comments_user_id', ['user_id'], unique=False)
        batch_op.create_index('ix_dump978_flight_comments_created_at', ['created_at'], unique=False)

    # ---- indexes for flight query performance ----
    with op.batch_alter_table('dump1090_flights') as batch_op:
        batch_op.create_index('ix_dump1090_flights_flight', ['flight'], unique=False)
        batch_op.create_index('ix_dump1090_flights_first_seen', ['first_seen'], unique=False)
        batch_op.create_index('ix_dump1090_flights_last_seen', ['last_seen'], unique=False)
        batch_op.create_index('ix_dump1090_flights_aircraft_class', ['aircraft_class'], unique=False)

    with op.batch_alter_table('dump978_flights') as batch_op:
        batch_op.create_index('ix_dump978_flights_flight', ['flight'], unique=False)
        batch_op.create_index('ix_dump978_flights_first_seen', ['first_seen'], unique=False)
        batch_op.create_index('ix_dump978_flights_last_seen', ['last_seen'], unique=False)
        batch_op.create_index('ix_dump978_flights_aircraft_class', ['aircraft_class'], unique=False)


def downgrade():
    # ---- drop in reverse dependency order ----
    with op.batch_alter_table('dump978_flights') as batch_op:
        batch_op.drop_index('ix_dump978_flights_aircraft_class')
        batch_op.drop_index('ix_dump978_flights_last_seen')
        batch_op.drop_index('ix_dump978_flights_first_seen')
        batch_op.drop_index('ix_dump978_flights_flight')

    with op.batch_alter_table('dump1090_flights') as batch_op:
        batch_op.drop_index('ix_dump1090_flights_aircraft_class')
        batch_op.drop_index('ix_dump1090_flights_last_seen')
        batch_op.drop_index('ix_dump1090_flights_first_seen')
        batch_op.drop_index('ix_dump1090_flights_flight')

    with op.batch_alter_table('dump978_flight_comments') as batch_op:
        batch_op.drop_index('ix_dump978_flight_comments_created_at')
        batch_op.drop_index('ix_dump978_flight_comments_user_id')
        batch_op.drop_index('ix_dump978_flight_comments_flight_id')
    op.drop_table('dump978_flight_comments')

    with op.batch_alter_table('dump1090_flight_comments') as batch_op:
        batch_op.drop_index('ix_dump1090_flight_comments_created_at')
        batch_op.drop_index('ix_dump1090_flight_comments_user_id')
        batch_op.drop_index('ix_dump1090_flight_comments_flight_id')
    op.drop_table('dump1090_flight_comments')

    op.drop_table('dump978_positions')
    op.drop_table('dump1090_positions')
    op.drop_table('dump978_flights')
    op.drop_table('dump1090_flights')

    with op.batch_alter_table('blog_comments') as batch_op:
        batch_op.drop_index('ix_blog_comments_created_at')
        batch_op.drop_index('ix_blog_comments_parent_comment_id')
        batch_op.drop_index('ix_blog_comments_user_id')
        batch_op.drop_index('ix_blog_comments_blog_post_id')
    op.drop_table('blog_comments')

    with op.batch_alter_table('notifications') as batch_op:
        batch_op.drop_index('ix_notifications_user_id')
    op.drop_table('notifications')

    op.drop_table('users')
    op.drop_table('settings')
    op.drop_table('opensky_aircraft')
    op.drop_table('links')

    with op.batch_alter_table('dump978_aircraft') as batch_op:
        batch_op.drop_index('ix_dump978_aircraft_icao')
    op.drop_table('dump978_aircraft')

    with op.batch_alter_table('dump1090_aircraft') as batch_op:
        batch_op.drop_index('ix_dump1090_aircraft_icao')
    op.drop_table('dump1090_aircraft')

    op.drop_table('blog_posts')
