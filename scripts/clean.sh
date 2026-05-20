#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Cleaning generated files..."

rm -rf "$ROOT_DIR/repo"
rm -rf "$ROOT_DIR/tmp"
rm -rf "$ROOT_DIR/cache"
rm -rf "$ROOT_DIR/metadata"
rm -f  "$ROOT_DIR/config.yml"
rm -f  "$ROOT_DIR/rclone.conf"
rm -f  "$ROOT_DIR/.signing_mode"

mkdir -p "$ROOT_DIR/repo" "$ROOT_DIR/tmp" "$ROOT_DIR/cache" "$ROOT_DIR/metadata"

echo "Clean complete. Run ./scripts/publish.sh to rebuild from scratch."
