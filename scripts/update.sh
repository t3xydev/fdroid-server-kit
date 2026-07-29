#!/usr/bin/env bash
# Incremental rebuild + optional S3 deploy (no clean). Used by webhooks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_env

"$SCRIPT_DIR/init.sh"
"$SCRIPT_DIR/build.sh"
"$SCRIPT_DIR/deploy.sh"

echo "Update complete (mode=$(resolve_mode))."
