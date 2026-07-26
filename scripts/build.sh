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

# -- Repo icon (persists across clean via assets/) -----------------------------

mkdir -p repo/icons
if [ -f "$ROOT_DIR/assets/icon.png" ]; then
  cp "$ROOT_DIR/assets/icon.png" repo/icons/icon.png
  echo "Copied assets/icon.png -> repo/icons/icon.png"
fi

# -- Verify APK signatures ----------------------------------------------------

if command -v apksigner &>/dev/null; then
  "$SCRIPT_DIR/verify.sh"
fi

# -- Update index ---------------------------------------------------------------

ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
KEYSTORE_FILE=$(grep -E '^KEYSTORE_FILE=' "$ENV_FILE" | cut -d= -f2 | tr -d '"' || echo "keystore.p12")

UPDATE_FLAGS=(--create-metadata --pretty)
if [ ! -f "$ROOT_DIR/${KEYSTORE_FILE}" ]; then
  UPDATE_FLAGS+=(--create-key)
fi

echo "Running fdroid update..."
fdroid update "${UPDATE_FLAGS[@]}"

echo "Build complete. Run ./scripts/publish.sh to deploy to S3."
