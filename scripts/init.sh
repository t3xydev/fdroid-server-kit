#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found. Copy .env.example to .env and fill in your values."
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "ERROR: $name is not set in $ENV_FILE"
    exit 1
  fi
}

REPO_SIGNED="${REPO_SIGNED:-true}"

require_var REPO_NAME
require_var REPO_URL

S3_READY="true"
S3_REQUIRED_VARS=(S3_REMOTE_NAME S3_PROVIDER S3_BUCKET S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY S3_ENDPOINT)
S3_MISSING=()

for var in "${S3_REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    S3_READY="false"
    S3_MISSING+=("$var")
  fi
done

if [ "$REPO_SIGNED" = "true" ]; then
  require_var KEYSTORE_FILE
  require_var REPO_KEYALIAS
  require_var KEYSTORE_PASS
  require_var KEY_PASS
  require_var KEYDNAME
fi

# -- Detect signing mode change ------------------------------------------------

STATE_FILE="$ROOT_DIR/.signing_mode"

if [ -f "$STATE_FILE" ]; then
  PREV_MODE=$(cat "$STATE_FILE")
  if [ "$PREV_MODE" != "$REPO_SIGNED" ]; then
    echo ""
    echo "WARNING: REPO_SIGNED changed from '$PREV_MODE' to '$REPO_SIGNED'."
    echo "You must clean and re-init for this to take effect:"
    echo ""
    echo "  ./scripts/clean.sh && ./scripts/init.sh"
    echo ""
    exit 1
  fi
fi

# -- Generate config.yml ------------------------------------------------------

cat > "$ROOT_DIR/config.yml" <<YAML
sdk_path: \$ANDROID_HOME
cachedir: cache

repo_url: ${REPO_URL}
repo_name: ${REPO_NAME}
repo_description: >-
  ${REPO_DESCRIPTION:-$REPO_NAME}

archive_older: 0

deploy_process_logs: true
YAML

if [ "$S3_READY" = "true" ]; then
  cat >> "$ROOT_DIR/config.yml" <<YAML

path_to_custom_rclone_config: ./rclone.conf
awsbucket: ${S3_BUCKET}
rclone_config: ${S3_REMOTE_NAME}
rclone: true
YAML
fi

if [ "$REPO_SIGNED" = "true" ]; then
  cat >> "$ROOT_DIR/config.yml" <<YAML

repo_keyalias: ${REPO_KEYALIAS}
keystore: ${KEYSTORE_FILE}
keystorepass: ${KEYSTORE_PASS}
keypass: ${KEY_PASS}
keydname: ${KEYDNAME}
YAML
fi

if [ -n "${REPO_WEB_BASE_URL:-}" ]; then
  echo "repo_web_base_url: ${REPO_WEB_BASE_URL}" >> "$ROOT_DIR/config.yml"
fi

echo "$REPO_SIGNED" > "$STATE_FILE"

echo "Generated config.yml (signed=$REPO_SIGNED)"

# -- Generate rclone.conf -----------------------------------------------------

if [ "$S3_READY" = "true" ]; then
  cat > "$ROOT_DIR/rclone.conf" <<INI
[${S3_REMOTE_NAME}]
type = s3
provider = ${S3_PROVIDER}
access_key_id = ${S3_ACCESS_KEY_ID}
secret_access_key = ${S3_SECRET_ACCESS_KEY}
region = ${S3_REGION:-auto}
endpoint = ${S3_ENDPOINT}
INI
  echo "Generated rclone.conf"
else
  echo "" > "$ROOT_DIR/rclone.conf"
  echo ""
  echo "WARNING: rclone.conf is empty -- missing S3 vars: ${S3_MISSING[*]}"
  echo "Deploy will not work until these are set in $ENV_FILE and you re-run init."
  echo ""
fi

# -- Ensure working directories exist -----------------------------------------

mkdir -p "$ROOT_DIR/apks" "$ROOT_DIR/repo" "$ROOT_DIR/metadata" \
         "$ROOT_DIR/tmp" "$ROOT_DIR/cache" "$ROOT_DIR/logs" "$ROOT_DIR/srclibs"

echo "Init complete."
