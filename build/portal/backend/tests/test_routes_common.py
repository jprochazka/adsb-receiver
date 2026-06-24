import pytest
from werkzeug.datastructures import MultiDict

from backend.routes.common import QueryParamError, get_stripped_arg, parse_bool_arg, parse_pagination


def test_parse_pagination_returns_defaults():
    offset, limit = parse_pagination(MultiDict(), default_limit=25, max_limit=100)

    assert offset == 0
    assert limit == 25


def test_parse_pagination_accepts_custom_values():
    offset, limit = parse_pagination(MultiDict({'offset': '5', 'limit': '10'}), default_limit=25, max_limit=100)

    assert offset == 5
    assert limit == 10


@pytest.mark.parametrize('query', [
    {'offset': '-1'},
    {'limit': '0'},
    {'limit': '101'},
    {'offset': 'abc'},
    {'limit': 'abc'},
])
def test_parse_pagination_rejects_invalid_values(query):
    with pytest.raises(QueryParamError, match='invalid offset or limit parameters'):
        parse_pagination(MultiDict(query), default_limit=25, max_limit=100)


@pytest.mark.parametrize(('raw', 'expected'), [
    ('true', True),
    ('TRUE', True),
    ('1', True),
    ('false', False),
    ('FALSE', False),
    ('0', False),
])
def test_parse_bool_arg_accepts_boolean_spellings(raw, expected):
    value = parse_bool_arg(MultiDict({'flag': raw}), 'flag', true_values={'true', '1'}, false_values={'false', '0'})

    assert value is expected


def test_parse_bool_arg_returns_none_when_missing_or_empty():
    assert parse_bool_arg(MultiDict(), 'flag', true_values={'true'}, false_values={'false'}) is None
    assert parse_bool_arg(MultiDict({'flag': ''}), 'flag', true_values={'true'}, false_values={'false'}) is None


def test_parse_bool_arg_rejects_invalid_value():
    with pytest.raises(QueryParamError, match='flag must be true or false'):
        parse_bool_arg(MultiDict({'flag': 'maybe'}), 'flag', true_values={'true'}, false_values={'false'})


def test_get_stripped_arg_normalizes_missing_and_whitespace():
    args = MultiDict({'q': '  hello  ', 'empty': '   '})

    assert get_stripped_arg(args, 'q') == 'hello'
    assert get_stripped_arg(args, 'empty') == ''
    assert get_stripped_arg(args, 'missing') == ''
    assert get_stripped_arg(args, 'missing', default='all') == 'all'
