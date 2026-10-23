PY ?= .venv/bin/python
PIP ?= .venv/bin/pip

.PHONY: help install dev db seed test migrate revise admin-dev admin-build check compose-up compose-down

help:
	@printf '%s\n' \
	  'install      create .venv and install backend dev dependencies' \
	  'dev          migrate, seed and serve the API on :8000' \
	  'db           run only the embedded PostgreSQL' \
	  'seed         seed idempotent demo data' \
	  'test         run the backend test suite' \
	  'migrate      apply Alembic migrations' \
	  'revise       autogenerate a migration (m=message required)' \
	  'admin-dev    run the operations console on :5173' \
	  'admin-build  typecheck and build the console' \
	  'check        tests + console build' \
	  'compose-up   build and start the local container stack' \
	  'compose-down stop the local container stack'

install:
	python3.12 -m venv .venv
	$(PIP) install -r backend/requirements-dev.txt

dev:
	$(PY) scripts/dev_backend.py

db:
	$(PY) scripts/dev_db.py

seed:
	$(PY) scripts/seed_demo.py

test:
	cd backend && ../$(PY) -m pytest -q

migrate:
	cd backend && ../$(PY) -m alembic upgrade head

revise:
	@test -n "$(m)" || (echo "usage: make revise m='message'" && exit 1)
	cd backend && ../$(PY) -m alembic revision --autogenerate -m "$(m)"

admin-dev:
	cd apps/admin_web && npm run dev

admin-build:
	cd apps/admin_web && npm run build

check: test admin-build

compose-up:
	cd infra && docker compose up --build

compose-down:
	cd infra && docker compose down
