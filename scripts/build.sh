#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# -- Generate configs if missing -----------------------------------------------

if [ ! -f config.yml ] || [ ! -f rclone.conf ]; then
  echo "Configs missing -- running init..."
  "$SCRIPT_DIR/init.sh"
fi

# -- Copy APKs -----------------------------------------------------------------

APK_COUNT=$(find apks/ -maxdepth 1 -name '*.apk' 2>/dev/null | wc -l | tr -d ' ')

if [ "$APK_COUNT" -eq 0 ]; then
  echo "No APKs found in apks/ -- nothing to build."
  exit 1
fi

echo "Copying $APK_COUNT APK(s) to repo/..."
cp apks/*.apk repo/

# -- Optional: verify signatures -----------------------------------------------

if command -v apksigner &>/dev/null; then
  "$SCRIPT_DIR/verify.sh"
fi

# -- Update index ---------------------------------------------------------------

echo "Running fdroid update..."
fdroid update --create-metadata --pretty

echo "Build complete. Run ./scripts/publish.sh to deploy to S3."
