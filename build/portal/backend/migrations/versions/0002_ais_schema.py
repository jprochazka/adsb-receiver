"""add AIS target and history tables

Revision ID: 0002
Revises: 0001
"""
from alembic import op
import sqlalchemy as sa


revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        'ais_targets',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('mmsi', sa.String(length=9), nullable=False),
        sa.Column('target_kind', sa.String(length=32), nullable=False, server_default='vessel'),
        sa.Column('imo', sa.String(length=10), nullable=True),
        sa.Column('callsign', sa.String(length=32), nullable=True),
        sa.Column('name', sa.String(length=128), nullable=True),
        sa.Column('vessel_type', sa.Integer(), nullable=True),
        sa.Column('dimensions', sa.JSON(), nullable=True),
        sa.Column('first_seen', sa.DateTime(), nullable=False),
        sa.Column('last_seen', sa.DateTime(), nullable=False),
        sa.Column('latitude', sa.Float(), nullable=True),
        sa.Column('longitude', sa.Float(), nullable=True),
        sa.Column('speed', sa.Float(), nullable=True),
        sa.Column('course', sa.Float(), nullable=True),
        sa.Column('heading', sa.Integer(), nullable=True),
        sa.Column('turn_rate', sa.Float(), nullable=True),
        sa.Column('navigation_status', sa.Integer(), nullable=True),
        sa.Column('channel', sa.String(length=16), nullable=True),
        sa.Column('position_timestamp', sa.DateTime(), nullable=True),
        sa.Column('static_report_timestamp', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('mmsi', 'target_kind', name='uq_ais_targets_mmsi_kind'),
    )
    op.create_index('ix_ais_targets_mmsi', 'ais_targets', ['mmsi'])
    op.create_index('ix_ais_targets_target_kind', 'ais_targets', ['target_kind'])
    op.create_index('ix_ais_targets_first_seen', 'ais_targets', ['first_seen'])
    op.create_index('ix_ais_targets_last_seen', 'ais_targets', ['last_seen'])
    op.create_index('ix_ais_targets_position_timestamp', 'ais_targets', ['position_timestamp'])
    op.create_index('ix_ais_targets_live_position', 'ais_targets', ['last_seen', 'latitude', 'longitude'])

    op.create_table(
        'ais_positions',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('target_id', sa.Integer(), nullable=False),
        sa.Column('received_at', sa.DateTime(), nullable=False),
        sa.Column('position_timestamp', sa.DateTime(), nullable=True),
        sa.Column('message_type', sa.Integer(), nullable=False),
        sa.Column('channel', sa.String(length=16), nullable=False),
        sa.Column('latitude', sa.Float(), nullable=True),
        sa.Column('longitude', sa.Float(), nullable=True),
        sa.Column('speed', sa.Float(), nullable=True),
        sa.Column('course', sa.Float(), nullable=True),
        sa.Column('heading', sa.Integer(), nullable=True),
        sa.Column('turn_rate', sa.Float(), nullable=True),
        sa.Column('navigation_status', sa.Integer(), nullable=True),
        sa.Column('signal_strength', sa.Float(), nullable=True),
        sa.Column('frequency', sa.Float(), nullable=True),
        sa.Column('fingerprint', sa.String(length=64), nullable=False),
        sa.ForeignKeyConstraint(['target_id'], ['ais_targets.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('target_id', 'fingerprint', name='uq_ais_positions_target_fingerprint'),
    )
    op.create_index('ix_ais_positions_target_id', 'ais_positions', ['target_id'])
    op.create_index('ix_ais_positions_received_at', 'ais_positions', ['received_at'])
    op.create_index('ix_ais_positions_position_timestamp', 'ais_positions', ['position_timestamp'])
    op.create_index('ix_ais_positions_track', 'ais_positions', ['target_id', 'received_at'])
    op.create_index('ix_ais_positions_live', 'ais_positions', ['received_at', 'latitude', 'longitude'])

    op.create_table(
        'ais_voyage_reports',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('target_id', sa.Integer(), nullable=False),
        sa.Column('reported_at', sa.DateTime(), nullable=False),
        sa.Column('imo', sa.String(length=10), nullable=True),
        sa.Column('callsign', sa.String(length=32), nullable=True),
        sa.Column('name', sa.String(length=128), nullable=True),
        sa.Column('vessel_type', sa.Integer(), nullable=True),
        sa.Column('dimensions', sa.JSON(), nullable=True),
        sa.Column('destination', sa.String(length=128), nullable=True),
        sa.Column('eta_month', sa.Integer(), nullable=True),
        sa.Column('eta_day', sa.Integer(), nullable=True),
        sa.Column('eta_hour', sa.Integer(), nullable=True),
        sa.Column('eta_minute', sa.Integer(), nullable=True),
        sa.Column('draught', sa.Float(), nullable=True),
        sa.ForeignKeyConstraint(['target_id'], ['ais_targets.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_ais_voyage_reports_target_id', 'ais_voyage_reports', ['target_id'])
    op.create_index('ix_ais_voyage_reports_reported_at', 'ais_voyage_reports', ['reported_at'])
    op.create_index('ix_ais_voyages_history', 'ais_voyage_reports', ['target_id', 'reported_at'])

    op.create_table(
        'ais_raw_messages',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('target_id', sa.Integer(), nullable=True),
        sa.Column('received_at', sa.DateTime(), nullable=False),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.Column('nmea', sa.Text(), nullable=True),
        sa.Column('payload', sa.Text(), nullable=True),
        sa.Column('channel', sa.String(length=16), nullable=True),
        sa.Column('message_type', sa.Integer(), nullable=True),
        sa.Column('decoder_version', sa.String(length=32), nullable=True),
        sa.ForeignKeyConstraint(['target_id'], ['ais_targets.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_ais_raw_messages_target_id', 'ais_raw_messages', ['target_id'])
    op.create_index('ix_ais_raw_messages_received_at', 'ais_raw_messages', ['received_at'])
    op.create_index('ix_ais_raw_messages_expires_at', 'ais_raw_messages', ['expires_at'])


def downgrade():
    op.drop_table('ais_raw_messages')
    op.drop_table('ais_voyage_reports')
    op.drop_table('ais_positions')
    op.drop_table('ais_targets')
