#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REPO_DIR="$ROOT_DIR/repo"

if ! command -v apksigner &>/dev/null; then
  echo "WARNING: apksigner not found -- skipping verification."
  echo "Install Android SDK build-tools or set ANDROID_HOME."
  exit 0
fi

APK_COUNT=0
FAIL_COUNT=0

for apk in "$REPO_DIR"/*.apk; do
  [ -f "$apk" ] || continue
  apkname=$(basename "$apk")
  APK_COUNT=$((APK_COUNT + 1))

  if apksigner verify "$apk" 2>/dev/null; then
    echo "OK  $apkname"
  else
    echo "FAIL  $apkname"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
done

if [ "$APK_COUNT" -eq 0 ]; then
  echo "No APKs found in repo/ to verify."
  exit 0
fi

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "FAILED: $FAIL_COUNT of $APK_COUNT APK(s) failed verification."
  exit 1
fi

echo "All $APK_COUNT APK(s) verified."
