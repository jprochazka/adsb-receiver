class QueryParamError(ValueError):
    """Raised when query string parameters fail route-level validation."""


INVALID_PAGINATION_MESSAGE = 'Bad Request - invalid offset or limit parameters'


def _get_int_arg(args, name, default, error_message=INVALID_PAGINATION_MESSAGE):
    raw = args.get(name, default=default)
    if raw is None or raw == '':
        return default
    try:
        return int(raw)
    except (TypeError, ValueError) as ex:
        raise QueryParamError(error_message) from ex


def parse_pagination(args, *, default_offset=0, default_limit=50, max_limit=100, error_message=None):
    message = error_message or INVALID_PAGINATION_MESSAGE
    offset = _get_int_arg(args, 'offset', default_offset, message)
    limit = _get_int_arg(args, 'limit', default_limit, message)

    if offset < 0 or limit < 1 or limit > max_limit:
        raise QueryParamError(message)

    return offset, limit


def parse_bool_arg(args, name, *, true_values=None, false_values=None, error_message=None):
    raw = args.get(name)
    if raw is None or raw == '':
        return None

    true_values = true_values or {'true'}
    false_values = false_values or {'false'}
    normalized = raw.strip().lower()
    if normalized in true_values:
        return True
    if normalized in false_values:
        return False

    message = error_message or f'{name} must be true or false'
    raise QueryParamError(message)


def get_stripped_arg(args, name, default=''):
    return (args.get(name) or default).strip()
