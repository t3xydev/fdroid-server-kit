#!/usr/bin/env bash
# Shared helpers for fdroid scripts. Source from other scripts:
#   SCRIPT_DIR=...; source "$SCRIPT_DIR/common.sh"

ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="${DATA_DIR:-$ROOT_DIR}"
mkdir -p "$DATA_DIR"
DATA_DIR="$(cd "$DATA_DIR" && pwd)"

ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
SECRETS_FILE="${SECRETS_FILE:-$DATA_DIR/.keystore_pass}"

load_env() {
  if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
  fi
  if [ -f "$DATA_DIR/.env" ] && [ "$DATA_DIR/.env" != "$ENV_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$DATA_DIR/.env"
    set +a
  fi
  # Persisted secrets only fill blanks (do not override explicit env/.env values)
  if [ -f "$SECRETS_FILE" ]; then
    if [ -z "${KEYSTORE_PASS:-}" ] || [ -z "${KEY_PASS:-}" ]; then
      # shellcheck source=/dev/null
      source "$SECRETS_FILE"
    fi
  fi
}

s3_ready() {
  local var
  for var in S3_REMOTE_NAME S3_PROVIDER S3_BUCKET S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY S3_ENDPOINT; do
    if [ -z "${!var:-}" ]; then
      return 1
    fi
  done
  return 0
}

is_self_host() {
  local flag
  flag="$(echo "${SELF_HOST:-}" | tr '[:upper:]' '[:lower:]')"
  case "$flag" in
    1|true|yes|on) return 0 ;;
  esac
  if s3_ready; then
    return 1
  fi
  return 0
}

resolve_mode() {
  if is_self_host; then
    echo "self_host"
  else
    echo "s3"
  fi
}

ensure_dirs() {
  mkdir -p "$DATA_DIR/apks" "$DATA_DIR/repo" "$DATA_DIR/metadata" \
           "$DATA_DIR/tmp" "$DATA_DIR/cache" "$DATA_DIR/logs" "$DATA_DIR/srclibs" \
           "$DATA_DIR/assets"
}

icon_source() {
  if [ -f "$DATA_DIR/assets/icon.png" ]; then
    echo "$DATA_DIR/assets/icon.png"
  elif [ -f "$ROOT_DIR/assets/icon.png" ]; then
    echo "$ROOT_DIR/assets/icon.png"
  else
    echo ""
  fi
}

keystore_path() {
  local file="${KEYSTORE_FILE:-keystore.p12}"
  if [[ "$file" = /* ]]; then
    echo "$file"
  else
    echo "$DATA_DIR/$file"
  fi
}
