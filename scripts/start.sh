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
# Init failure must not block serving an existing repo.
echo "Syncing config from env (DATA_DIR=$DATA_DIR)..."
if ! "$SCRIPT_DIR/init.sh"; then
  echo "WARNING: init.sh failed — continuing with existing config if present."
fi

# Rebuild the repo index when env-driven settings that affect the index change.
# Rebuild runs in the background so a failed fdroid update cannot crash the service.
FINGERPRINT_FILE="$DATA_DIR/.env_fingerprint"
env_fingerprint() {
  local payload
  payload="$(printf '%s\0' \
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
    "${S3_SECRET_ACCESS_KEY:-}")"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$payload" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$payload" | openssl dgst -sha256 | awk '{print $NF}'
  fi
}

NEW_FP="$(env_fingerprint)"
OLD_FP=""
if [ -f "$FINGERPRINT_FILE" ]; then
  OLD_FP="$(tr -d '[:space:]' < "$FINGERPRINT_FILE")"
fi

APK_COUNT=$(find "$DATA_DIR/apks" -maxdepth 1 -name '*.apk' 2>/dev/null | wc -l | tr -d ' ')

maybe_rebuild() {
  if [ "$APK_COUNT" -eq 0 ]; then
    echo "No APKs yet — skipping rebuild."
    echo "$NEW_FP" > "$FINGERPRINT_FILE"
    return 0
  fi
  if [ "$NEW_FP" = "$OLD_FP" ]; then
    echo "Env fingerprint unchanged — serving existing repo."
    return 0
  fi
  echo "Env/config fingerprint changed — rebuilding repo index in background..."
  if "$SCRIPT_DIR/update.sh"; then
    echo "$NEW_FP" > "$FINGERPRINT_FILE"
    echo "Background rebuild complete."
  else
    echo "WARNING: background rebuild failed — serving previous repo if any."
  fi
}

# Kick off rebuild without blocking uvicorn (Railway healthchecks need the port up).
maybe_rebuild &

PORT="${PORT:-8000}"
exec python3 -m uvicorn backend.main:app --host 0.0.0.0 --port "$PORT"
