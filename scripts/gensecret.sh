#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

generate_secret() {
  openssl rand -base64 32 | tr -d '/+=' | head -c 32
}

SECRET=$(generate_secret)

write_secrets_file() {
  cat > "$SECRETS_FILE" <<EOF
KEYSTORE_PASS="${SECRET}"
KEY_PASS="${SECRET}"
EOF
  chmod 600 "$SECRETS_FILE" 2>/dev/null || true
  echo "Wrote keystore secret to $SECRETS_FILE"
}

set_env_var() {
  local file="$1"
  local key="$2"
  local value="$3"
  if grep -qE "^${key}=" "$file"; then
    # Portable in-place edit (macOS + GNU sed)
    if sed --version >/dev/null 2>&1; then
      sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$file"
    else
      sed -i '' "s|^${key}=.*|${key}=\"${value}\"|" "$file"
    fi
  else
    echo "${key}=\"${value}\"" >> "$file"
  fi
}

if [ -f "$ENV_FILE" ]; then
  set_env_var "$ENV_FILE" KEYSTORE_PASS "$SECRET"
  set_env_var "$ENV_FILE" KEY_PASS "$SECRET"
  echo "Generated keystore secret and wrote to $ENV_FILE"
else
  echo "No .env at $ENV_FILE -- persisting secret under DATA_DIR."
  write_secrets_file
fi

# Always keep a copy in DATA_DIR so Docker restarts keep the same passwords
write_secrets_file

echo "KEYSTORE_PASS and KEY_PASS set to the same random value."
echo ""
echo "If you already have a keystore, regenerate it after changing passwords:"
echo "  rm \"\${DATA_DIR:-.}/keystore.p12\" && ./scripts/clean.sh && ./scripts/init.sh"
