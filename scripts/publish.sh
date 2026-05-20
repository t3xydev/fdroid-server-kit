#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# -- Build (copy APKs + update index) -----------------------------------------

"$SCRIPT_DIR/build.sh"

# -- Deploy to S3 ---------------------------------------------------------------

echo "Running fdroid deploy..."
fdroid deploy

echo "Publish complete."
