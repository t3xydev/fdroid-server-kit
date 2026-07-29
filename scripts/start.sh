#!/usr/bin/env bash
# Portable container start — Docker Compose, plain Docker, Railway, etc.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

export DATA_DIR="${DATA_DIR:-/data}"
mkdir -p "$DATA_DIR"
DATA_DIR="$(cd "$DATA_DIR" && pwd)"
export DATA_DIR

load_env

# Always rewrite config.yml / rclone.conf from current env (never touches apks/).
echo "Syncing config from env (DATA_DIR=$DATA_DIR)..."
"$SCRIPT_DIR/init.sh"

# Rebuild the repo index when env-driven settings that affect the index change.
# Without this, Railway env edits leave a stale signed index on the volume.
FINGERPRINT_FILE="$DATA_DIR/.env_fingerprint"
env_fingerprint() {
  printf '%s\0' \
    "${REPO_NAME:-}" \
    "${REPO_URL:-}" \
    "${REPO_DESCRIPTION:-}" \
    "${REPO_WEB_BASE_URL:-}" \
    "${SELF_HOST:-}" \
    "${KEYDNAME:-}" \
    "${REPO_KEYALIAS:-}" \
    "${KEYSTORE_FILE:-}" \
    "${S3_REMOTE_NAME:-}" \
    "${S3_PROVIDER:-}" \
    "${S3_BUCKET:-}" \
    "${S3_ENDPOINT:-}" \
    "${S3_REGION:-}" \
    "${S3_ACCESS_KEY_ID:-}" \
    "${S3_SECRET_ACCESS_KEY:-}" \
    | sha256sum | awk '{print $1}'
}

NEW_FP="$(env_fingerprint)"
OLD_FP=""
if [ -f "$FINGERPRINT_FILE" ]; then
  OLD_FP="$(cat "$FINGERPRINT_FILE")"
fi

APK_COUNT=$(find "$DATA_DIR/apks" -maxdepth 1 -name '*.apk' 2>/dev/null | wc -l | tr -d ' ')

if [ "$APK_COUNT" -gt 0 ] && [ "$NEW_FP" != "$OLD_FP" ]; then
  echo "Env/config fingerprint changed — rebuilding repo index..."
  "$SCRIPT_DIR/update.sh"
  echo "$NEW_FP" > "$FINGERPRINT_FILE"
elif [ "$APK_COUNT" -eq 0 ]; then
  echo "No APKs yet — skipping rebuild. Drop APKs or call webhook, then update."
  echo "$NEW_FP" > "$FINGERPRINT_FILE"
else
  echo "Env fingerprint unchanged — serving existing repo."
fi

# Railway and other PaaS inject PORT; local Docker defaults to 8000
PORT="${PORT:-8000}"

exec python3 -m uvicorn backend.main:app --host 0.0.0.0 --port "$PORT"
