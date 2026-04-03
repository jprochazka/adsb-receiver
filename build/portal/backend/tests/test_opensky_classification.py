import os

from backend.opensky_classification import (
    clear_opensky_classification_cache,
    get_opensky_cache_stats,
    get_opensky_classification,
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
        assert stats['loaded_at'] is not None

        os.remove(csv_path)
        clear_opensky_classification_cache()
