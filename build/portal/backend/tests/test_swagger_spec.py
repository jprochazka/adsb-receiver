def _swagger_spec(client):
    response = client.get('/api/swagger.json')
    assert response.status_code == 200
    return response.get_json()


def _operation(spec, path, method='get'):
    return spec['paths'][path][method]


def _parameters(spec, path, method='get'):
    path_item = spec['paths'][path]
    return path_item.get('parameters', []) + path_item[method].get('parameters', [])


def _query_param_names(spec, path, method='get'):
    return {
        parameter['name']
        for parameter in _parameters(spec, path, method)
        if parameter.get('in') == 'query'
    }


def _path_param_names(spec, path, method='get'):
    return {
        parameter['name']
        for parameter in _parameters(spec, path, method)
        if parameter.get('in') == 'path'
    }


def _response_schema_ref(spec, path, method, status='200'):
    response = _operation(spec, path, method)['responses'][status]
    schema = response.get('schema', {})
    return schema.get('$ref')


def test_swagger_api_title_and_live_namespace_wording(client):
    spec = _swagger_spec(client)

    assert spec['info']['title'] == 'ADS-B Receiver Portal API'
    assert 'ADS-B receiver data' in spec['info']['description']
    live_tag = next(tag for tag in spec['tags'] if tag['name'] == 'live')
    assert live_tag['description'] == 'Live aircraft data from dump1090 and dump978'


def test_swagger_documents_adsb_flight_read_endpoints(client):
    spec = _swagger_spec(client)

    assert _response_schema_ref(spec, '/adsb/flights', 'get') == '#/definitions/FlightsList'
    assert _query_param_names(spec, '/adsb/flights') == {'offset', 'limit', 'q', 'ignore_on_purge'}
    assert set(_operation(spec, '/adsb/flights', 'get')['responses']) >= {'200', '400', '500'}

    assert _response_schema_ref(spec, '/adsb/flights/search', 'get') == '#/definitions/FlightsList'
    assert _query_param_names(spec, '/adsb/flights/search') == {'q', 'ignore_on_purge'}
    assert set(_operation(spec, '/adsb/flights/search', 'get')['responses']) >= {'200', '400', '500'}

    assert _response_schema_ref(spec, '/adsb/flights/count', 'get') == '#/definitions/FlightCount'

    assert _response_schema_ref(spec, '/adsb/flight/{flight}', 'get') == '#/definitions/Flight'
    assert _path_param_names(spec, '/adsb/flight/{flight}') == {'flight'}
    assert set(_operation(spec, '/adsb/flight/{flight}', 'get')['responses']) >= {'200', '404', '500'}

    assert _response_schema_ref(spec, '/adsb/flight/{flight}/positions', 'get') == '#/definitions/PositionsList'
    assert _path_param_names(spec, '/adsb/flight/{flight}/positions') == {'flight'}
    assert _query_param_names(spec, '/adsb/flight/{flight}/positions') == {'offset', 'limit'}
    assert set(_operation(spec, '/adsb/flight/{flight}/positions', 'get')['responses']) >= {'200', '400', '404', '500'}

    assert _query_param_names(spec, '/adsb/flights/purge', 'delete') == {'days'}


def test_swagger_documents_uat_flight_read_endpoints(client):
    spec = _swagger_spec(client)

    assert _response_schema_ref(spec, '/uat/flights', 'get') == '#/definitions/UATFlightsList'
    assert _query_param_names(spec, '/uat/flights') == {'offset', 'limit', 'q', 'ignore_on_purge'}
    assert set(_operation(spec, '/uat/flights', 'get')['responses']) >= {'200', '400', '500'}

    assert _response_schema_ref(spec, '/uat/flights/search', 'get') == '#/definitions/UATFlightsList'
    assert _query_param_names(spec, '/uat/flights/search') == {'q', 'ignore_on_purge'}
    assert set(_operation(spec, '/uat/flights/search', 'get')['responses']) >= {'200', '400', '500'}

    assert _response_schema_ref(spec, '/uat/flights/count', 'get') == '#/definitions/UATFlightCount'

    assert _response_schema_ref(spec, '/uat/flight/{flight}', 'get') == '#/definitions/UATFlight'
    assert _path_param_names(spec, '/uat/flight/{flight}') == {'flight'}
    assert set(_operation(spec, '/uat/flight/{flight}', 'get')['responses']) >= {'200', '404', '500'}

    assert _response_schema_ref(spec, '/uat/flight/{flight}/positions', 'get') == '#/definitions/UATPositionsList'
    assert _path_param_names(spec, '/uat/flight/{flight}/positions') == {'flight'}
    assert _query_param_names(spec, '/uat/flight/{flight}/positions') == {'offset', 'limit'}
    assert set(_operation(spec, '/uat/flight/{flight}/positions', 'get')['responses']) >= {'200', '400', '404', '500'}

    assert _query_param_names(spec, '/uat/flights/purge', 'delete') == {'days'}


def test_swagger_documents_acars_read_endpoints(client):
    spec = _swagger_spec(client)

    assert _response_schema_ref(spec, '/acars/flights', 'get') == '#/definitions/AcarsFlightsList'
    assert _query_param_names(spec, '/acars/flights') == {'offset', 'limit'}
    assert set(_operation(spec, '/acars/flights', 'get')['responses']) >= {'200', '400', '500', '503'}

    assert _response_schema_ref(spec, '/acars/flights/count', 'get') == '#/definitions/AcarsFlightCount'
    assert set(_operation(spec, '/acars/flights/count', 'get')['responses']) >= {'200', '500', '503'}

    assert _response_schema_ref(spec, '/acars/flights/database', 'get') == '#/definitions/AcarsDatabaseInfo'
    assert set(_operation(spec, '/acars/flights/database', 'get')['responses']) >= {'200', '500', '503'}

    assert _response_schema_ref(spec, '/acars/flight/{flight_id}/messages', 'get') == '#/definitions/AcarsMessagesList'
    assert _path_param_names(spec, '/acars/flight/{flight_id}/messages') == {'flight_id'}
    assert _query_param_names(spec, '/acars/flight/{flight_id}/messages') == {'offset', 'limit'}
    assert set(_operation(spec, '/acars/flight/{flight_id}/messages', 'get')['responses']) >= {'200', '400', '404', '500', '503'}

    assert _response_schema_ref(spec, '/acars/messages/count', 'get') == '#/definitions/AcarsMessagesCount'
    assert set(_operation(spec, '/acars/messages/count', 'get')['responses']) >= {'200', '500', '503'}

    assert _query_param_names(spec, '/acars/flights/purge', 'delete') == {'days'}


def test_swagger_documents_dumpvdl2_config(client):
    spec = _swagger_spec(client)

    config_get = _operation(spec, '/dumpvdl2/config')
    assert config_get['security'] == [{'Bearer': []}]
    assert _response_schema_ref(spec, '/dumpvdl2/config', 'get') == '#/definitions/Dumpvdl2Config'

    config_put = _operation(spec, '/dumpvdl2/config', 'put')
    assert config_put['security'] == [{'Bearer': []}]
    assert _response_schema_ref(spec, '/dumpvdl2/config', 'put') == '#/definitions/Dumpvdl2Config'
    assert set(config_put['responses']) >= {'200', '400', '401', '403', '503'}


def test_swagger_documents_x_alert_endpoints(client):
    spec = _swagger_spec(client)

    config_get = _operation(spec, '/x-alert/config')
    assert config_get['operationId'] == 'get_x_alert_config'
    assert config_get['security'] == [{'Bearer': []}]
    assert _response_schema_ref(spec, '/x-alert/config', 'get') == '#/definitions/XAlertConfig'
    assert set(config_get['responses']) >= {'200', '401', '403'}

    config_put = _operation(spec, '/x-alert/config', 'put')
    assert config_put['operationId'] == 'update_x_alert_config'
    assert config_put['security'] == [{'Bearer': []}]
    assert next(parameter for parameter in config_put['parameters'] if parameter['in'] == 'body')[
        'schema'
    ]['$ref'] == '#/definitions/UpdateXAlertConfig'
    assert _response_schema_ref(spec, '/x-alert/config', 'put') == '#/definitions/XAlertConfig'
    assert set(config_put['responses']) >= {'200', '400', '401', '403'}

    status = _operation(spec, '/x-alert/status')
    assert status['operationId'] == 'get_x_alert_status'
    assert _response_schema_ref(spec, '/x-alert/status', 'get') == '#/definitions/XAlertStatus'
    assert set(status['responses']) >= {'200', '401', '403'}

    dry_run = _operation(spec, '/x-alert/dry-run', 'post')
    assert dry_run['operationId'] == 'dry_run_x_alert'
    assert _response_schema_ref(spec, '/x-alert/dry-run', 'post') == '#/definitions/XAlertCycleResult'
    assert set(dry_run['responses']) >= {'200', '401', '403'}

    send = _operation(spec, '/x-alert/send', 'post')
    assert send['operationId'] == 'send_x_alert'
    assert _response_schema_ref(spec, '/x-alert/send', 'post') == '#/definitions/XAlertCycleResult'
    assert set(send['responses']) >= {'200', '401', '403', '502'}
