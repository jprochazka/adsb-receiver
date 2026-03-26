from unittest.mock import patch, MagicMock

from backend.jobs.rrd_data_collection import rrd_data_collection_job


@patch('backend.jobs.rrd_data_collection.RrdWriter')
def test_rrd_data_collection_job_runs_writer(mock_writer_cls, app):
    writer = MagicMock()
    mock_writer_cls.return_value = writer

    with app.app_context():
        rrd_data_collection_job()

    mock_writer_cls.assert_called_once()
    writer.run.assert_called_once()


@patch('backend.jobs.rrd_data_collection.logging.error')
@patch('backend.jobs.rrd_data_collection.RrdWriter', side_effect=FileNotFoundError())
def test_rrd_data_collection_job_handles_missing_rrdtool(mock_writer_cls, mock_log_error, app):
    with app.app_context():
        rrd_data_collection_job()

    mock_log_error.assert_called_once()
