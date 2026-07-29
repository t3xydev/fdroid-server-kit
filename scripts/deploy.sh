#!/usr/bin/env bash
# Deploy to S3 if configured; succeed with self-host message otherwise.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_env
cd "$DATA_DIR"

if [ ! -s "$DATA_DIR/rclone.conf" ]; then
  MODE="$(resolve_mode)"
  echo "S3 not configured -- skipping remote deploy (mode=$MODE)."
  echo "Repo is available under $DATA_DIR/repo/ for self-host."
  exit 0
fi

echo "Running fdroid deploy..."
fdroid deploy
echo "Deploy complete."
