# AIS Reference Fixtures

These fixtures are sanitized protocol-reference packets for parser and schema
work. They are not hardware captures and must not be treated as evidence that
an RTL-SDR or both AIS channels are receiving locally.

The payload shapes follow the AIS-catcher main-branch `JSON_FULL` documentation. Identity,
coordinates, timestamps, NMEA payloads, and signal values are synthetic or
sanitized. The receive timestamp is only suitable for fixture inspection; tests
that call the live clock validator should construct a current timestamp.
