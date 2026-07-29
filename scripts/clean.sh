#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

echo "Cleaning generated files in $DATA_DIR..."

rm -rf "$DATA_DIR/repo"
rm -rf "$DATA_DIR/tmp"
rm -rf "$DATA_DIR/cache"
rm -rf "$DATA_DIR/metadata"
rm -f  "$DATA_DIR/config.yml"
rm -f  "$DATA_DIR/rclone.conf"

mkdir -p "$DATA_DIR/repo" "$DATA_DIR/tmp" "$DATA_DIR/cache" "$DATA_DIR/metadata"

echo "Clean complete. Run ./scripts/publish.sh to rebuild from scratch."
