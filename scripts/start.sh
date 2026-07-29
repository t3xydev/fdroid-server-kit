#!/usr/bin/env bash
# Portable container start — Docker Compose, plain Docker, Railway, etc.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

export DATA_DIR="${DATA_DIR:-/data}"
mkdir -p "$DATA_DIR"

# First boot only: create config.yml / rclone.conf if missing.
# Does not touch apks/. Env changes are picked up on publish (update.sh → init).
if [ ! -f "$DATA_DIR/config.yml" ]; then
  echo "No config.yml yet — running init (DATA_DIR=$DATA_DIR)..."
  "$SCRIPT_DIR/init.sh"
else
  echo "config.yml present — skipping boot init (apks/ and data preserved)."
fi

# Railway and other PaaS inject PORT; local Docker defaults to 8000
PORT="${PORT:-8000}"

exec python3 -m uvicorn backend.main:app --host 0.0.0.0 --port "$PORT"
