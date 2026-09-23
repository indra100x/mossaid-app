# Mossaid Backend

FastAPI skeleton (Python 3.12).

## Local dev

```bash
docker compose up --build
# API at http://localhost:8000 — docs at /docs
```

## Migrations

```bash
alembic revision --autogenerate -m "message"
alembic upgrade head
```

## Tests / Lint

```bash
pip install -e ".[dev]"
ruff check .
mypy .
pytest
```
