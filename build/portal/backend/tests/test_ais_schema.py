from sqlalchemy import inspect


def test_ais_tables_and_indexes_are_created(app):
    with app.app_context():
        inspector = inspect(app.extensions['sqlalchemy'].engine)
        tables = set(inspector.get_table_names())
        assert {'ais_targets', 'ais_positions', 'ais_voyage_reports', 'ais_raw_messages'} <= tables

        target_indexes = {index['name'] for index in inspector.get_indexes('ais_targets')}
        position_indexes = {index['name'] for index in inspector.get_indexes('ais_positions')}
        raw_indexes = {index['name'] for index in inspector.get_indexes('ais_raw_messages')}
        assert 'ix_ais_targets_live_position' in target_indexes
        assert 'ix_ais_positions_track' in position_indexes
        assert 'ix_ais_raw_messages_expires_at' in raw_indexes


def test_ais_foreign_keys_cascade(app):
    with app.app_context():
        inspector = inspect(app.extensions['sqlalchemy'].engine)
        for table in ('ais_positions', 'ais_voyage_reports', 'ais_raw_messages'):
            foreign_keys = inspector.get_foreign_keys(table)
            assert any(
                foreign_key['referred_table'] == 'ais_targets'
                and foreign_key['options'].get('ondelete') == 'CASCADE'
                for foreign_key in foreign_keys
            )
