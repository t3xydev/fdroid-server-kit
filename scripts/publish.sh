#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# -- Clean + rebuild from scratch ---------------------------------------------

"$SCRIPT_DIR/clean.sh"
"$SCRIPT_DIR/init.sh"
"$SCRIPT_DIR/build.sh"

# -- Deploy to S3 ---------------------------------------------------------------

if [ ! -s "$ROOT_DIR/rclone.conf" ]; then
  echo "ERROR: rclone.conf is empty -- S3 vars are not configured."
  echo "Set the S3_* variables in .env and run: ./scripts/init.sh"
  exit 1
fi

echo "Running fdroid deploy..."
fdroid deploy

echo "Publish complete."
