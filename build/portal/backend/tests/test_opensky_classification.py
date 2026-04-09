import os

from backend.opensky_classification import (
    clear_opensky_classification_cache,
    get_opensky_cache_stats,
    get_opensky_classification,
    get_opensky_classification_by_registration,
    import_opensky_csv,
)


def test_get_opensky_classification_without_app_context_returns_none():
    clear_opensky_classification_cache()

    klass, source, confidence = get_opensky_classification('abc123')

    assert klass is None
    assert source is None
    assert confidence is None


def test_get_opensky_classification_loads_from_instance_csv(app):
    with app.app_context():
        clear_opensky_classification_cache()

        opensky_dir = os.path.join(app.instance_path, 'opensky')
        os.makedirs(opensky_dir, exist_ok=True)
        csv_path = os.path.join(opensky_dir, 'aircraftDatabase.csv')
        with open(csv_path, 'w', encoding='utf-8') as handle:
            handle.write('icao24,typecode,categoryDescription\n')
            handle.write('abc123,C172,\n')
            handle.write('def456,,Rotorcraft\n')

        import_opensky_csv()

        klass1, source1, confidence1 = get_opensky_classification('abc123')
        klass2, source2, confidence2 = get_opensky_classification('def456')

        assert klass1 == 'general_aviation'
        assert source1 == 'opensky'
        assert confidence1 == 'low'

        assert klass2 == 'helicopter'
        assert source2 == 'opensky'
        assert confidence2 == 'high'

        stats = get_opensky_cache_stats()
        assert stats['entries'] == 2

        os.remove(csv_path)
        clear_opensky_classification_cache()


def test_get_opensky_classification_by_registration_uses_normalized_registration(app):
    with app.app_context():
        clear_opensky_classification_cache()

        opensky_dir = os.path.join(app.instance_path, 'opensky')
        os.makedirs(opensky_dir, exist_ok=True)
        csv_path = os.path.join(opensky_dir, 'aircraftDatabase.csv')
        with open(csv_path, 'w', encoding='utf-8') as handle:
            handle.write('icao24,registration,typecode,categoryDescription\n')
            handle.write('abc123,N-123AB,C172,\n')

        import_opensky_csv()

        klass, source, confidence = get_opensky_classification_by_registration('n123ab')
        assert klass == 'general_aviation'
        assert source == 'opensky'
        assert confidence == 'low'

        missing_klass, missing_source, missing_confidence = get_opensky_classification_by_registration('N999ZZ')
        assert missing_klass is None
        assert missing_source is None
        assert missing_confidence is None

        os.remove(csv_path)
        clear_opensky_classification_cache()
