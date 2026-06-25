# Backend Testing

These commands are for the Flask backend in `build/portal/backend`.

## System packages

On Ubuntu/Debian, install Python virtual environment support and native database driver build dependencies:

```bash
sudo apt update
sudo apt install -y \
  python3.12-venv \
  python3-pip \
  build-essential \
  pkg-config \
  default-libmysqlclient-dev \
  libpq-dev
```

`rrdtool` is needed for runtime graph generation. The current unit test suite does not require it to pass, but install it for deployment/runtime validation:

```bash
sudo apt install -y rrdtool
```

## Create a virtual environment

```bash
cd build/portal/backend
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -U pip setuptools wheel
```

## Install dependencies

```bash
python -m pip install -r requirements.txt
```

## Run tests

```bash
python -m pytest -q
```

Expected baseline when this plan was created:

```text
452 passed
```

## Run coverage

Coverage is configured in `pyproject.toml` and should be run from `build/portal/backend`:

```bash
python -m coverage erase
python -m coverage run -m pytest -q
python -m coverage report -m
```

This command uses `[tool.coverage.run]` to measure the `backend` package with branch coverage enabled.
Do not add a hard coverage fail-under gate until the project has intentionally improved and agreed on a stable baseline.

## Additional validation

```bash
python -m compileall backend tests
```

If Ruff is enabled in this project, also run:

```bash
ruff check .
```
