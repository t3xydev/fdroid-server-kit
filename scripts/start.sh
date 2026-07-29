#!/usr/bin/env bash
# Portable container start — Docker Compose, plain Docker, Railway, etc.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

export DATA_DIR="${DATA_DIR:-/data}"
mkdir -p "$DATA_DIR"

# Sync config.yml / rclone.conf from env on every boot
echo "Running init on boot (DATA_DIR=$DATA_DIR)..."
"$SCRIPT_DIR/init.sh"

# Railway and other PaaS inject PORT; local Docker defaults to 8000
PORT="${PORT:-8000}"

exec python3 -m uvicorn backend.main:app --host 0.0.0.0 --port "$PORT"
