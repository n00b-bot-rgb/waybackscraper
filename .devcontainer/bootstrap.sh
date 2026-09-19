#!/usr/bin/env bash
set -euo pipefail

echo "Codespaces environment ready."
docker --version
docker compose version
node --version 2>/dev/null || true
python3 --version 2>/dev/null || true
go version 2>/dev/null || true

if [[ "${DEVCONTAINER_INSTALL_PROJECT_DEPS:-0}" != "1" ]]; then
  echo "Dependency install skipped. Set DEVCONTAINER_INSTALL_PROJECT_DEPS=1 and rebuild to opt in."
  exit 0
fi

if [[ -f package-lock.json ]]; then
  npm ci
elif [[ -f package.json ]]; then
  npm install
fi

if [[ -f requirements.txt ]]; then
  python3 -m pip install -r requirements.txt
elif [[ -f pyproject.toml || -f setup.py ]]; then
  python3 -m pip install -e .
fi

if [[ -f go.mod ]]; then
  go mod download
fi
