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

require_var REPO_NAME
require_var REPO_URL
require_var KEYSTORE_FILE
require_var REPO_KEYALIAS
require_var KEYSTORE_PASS
require_var KEY_PASS
require_var KEYDNAME
require_var S3_REMOTE_NAME
require_var S3_PROVIDER
require_var S3_BUCKET
require_var S3_ACCESS_KEY_ID
require_var S3_SECRET_ACCESS_KEY
require_var S3_ENDPOINT

# -- Generate config.yml ------------------------------------------------------

cat > "$ROOT_DIR/config.yml" <<YAML
sdk_path: \$ANDROID_HOME
cachedir: cache

repo_url: ${REPO_URL}
repo_name: ${REPO_NAME}
repo_description: >-
  ${REPO_DESCRIPTION:-$REPO_NAME}

archive_older: 0

repo_keyalias: ${REPO_KEYALIAS}
keystore: ${KEYSTORE_FILE}
keystorepass: ${KEYSTORE_PASS}
keypass: ${KEY_PASS}
keydname: ${KEYDNAME}

deploy_process_logs: true

path_to_custom_rclone_config: ./rclone.conf
awsbucket: ${S3_BUCKET}
rclone_config: ${S3_REMOTE_NAME}
rclone: true
YAML

if [ -n "${REPO_WEB_BASE_URL:-}" ]; then
  echo "repo_web_base_url: ${REPO_WEB_BASE_URL}" >> "$ROOT_DIR/config.yml"
fi

echo "Generated config.yml"

# -- Generate rclone.conf -----------------------------------------------------

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

# -- Ensure working directories exist -----------------------------------------

mkdir -p "$ROOT_DIR/apks" "$ROOT_DIR/repo" "$ROOT_DIR/metadata" \
         "$ROOT_DIR/tmp" "$ROOT_DIR/cache" "$ROOT_DIR/logs" "$ROOT_DIR/srclibs"

echo "Init complete."
