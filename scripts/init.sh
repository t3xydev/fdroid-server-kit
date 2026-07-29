#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_env

# Sensible defaults when running with compose-injected env only
REPO_NAME="${REPO_NAME:-F-Droid Repository}"
REPO_URL="${REPO_URL:-http://localhost:8000/fdroid/repo}"
KEYSTORE_FILE="${KEYSTORE_FILE:-keystore.p12}"
REPO_KEYALIAS="${REPO_KEYALIAS:-keystore.local}"
KEYDNAME="${KEYDNAME:-CN=keystore.local, OU=F-Droid}"

require_var() {
  local name="$1"
  if [ -z "${!name:-}" ]; then
    echo "ERROR: $name is not set (env or .env)"
    exit 1
  fi
}

require_var REPO_NAME
require_var REPO_URL
require_var KEYSTORE_FILE
require_var REPO_KEYALIAS
require_var KEYDNAME

# Auto-generate keystore passwords if left blank
if [ -z "${KEYSTORE_PASS:-}" ] || [ -z "${KEY_PASS:-}" ]; then
  echo "KEYSTORE_PASS/KEY_PASS blank -- generating secret..."
  "$SCRIPT_DIR/gensecret.sh"
  load_env
fi

require_var KEYSTORE_PASS
require_var KEY_PASS

S3_READY="false"
S3_MISSING=()
S3_REQUIRED_VARS=(S3_REMOTE_NAME S3_PROVIDER S3_BUCKET S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY S3_ENDPOINT)

for var in "${S3_REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    S3_MISSING+=("$var")
  fi
done

if [ "${#S3_MISSING[@]}" -eq 0 ]; then
  S3_READY="true"
fi

ensure_dirs

# Keystore path in config.yml: relative name is fine when cwd is DATA_DIR
KS_FILE="${KEYSTORE_FILE:-keystore.p12}"
if [[ "$KS_FILE" = /* ]]; then
  KS_CONFIG="$KS_FILE"
else
  KS_CONFIG="$KS_FILE"
fi

# -- Generate config.yml ------------------------------------------------------

cat > "$DATA_DIR/config.yml" <<YAML
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
  cat >> "$DATA_DIR/config.yml" <<YAML

path_to_custom_rclone_config: ./rclone.conf
awsbucket: ${S3_BUCKET}
rclone_config: ${S3_REMOTE_NAME}
rclone: true
YAML
fi

cat >> "$DATA_DIR/config.yml" <<YAML

repo_keyalias: ${REPO_KEYALIAS}
keystore: ${KS_CONFIG}
keystorepass: ${KEYSTORE_PASS}
keypass: ${KEY_PASS}
keydname: ${KEYDNAME}
YAML

if [ -n "${REPO_WEB_BASE_URL:-}" ]; then
  echo "repo_web_base_url: ${REPO_WEB_BASE_URL}" >> "$DATA_DIR/config.yml"
fi

echo "Generated $DATA_DIR/config.yml"

# -- Generate rclone.conf -----------------------------------------------------

if [ "$S3_READY" = "true" ]; then
  cat > "$DATA_DIR/rclone.conf" <<INI
[${S3_REMOTE_NAME}]
type = s3
provider = ${S3_PROVIDER}
access_key_id = ${S3_ACCESS_KEY_ID}
secret_access_key = ${S3_SECRET_ACCESS_KEY}
region = ${S3_REGION:-auto}
endpoint = ${S3_ENDPOINT}
INI
  echo "Generated $DATA_DIR/rclone.conf"
else
  echo "" > "$DATA_DIR/rclone.conf"
  echo ""
  echo "WARNING: rclone.conf is empty -- missing S3 vars: ${S3_MISSING[*]}"
  echo "Self-host mode: local repo will be served; deploy to S3 is skipped."
  echo ""
fi

MODE="$(resolve_mode)"
echo "Mode: $MODE"
echo "Init complete (DATA_DIR=$DATA_DIR)."
