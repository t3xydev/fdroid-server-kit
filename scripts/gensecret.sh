#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"

generate_secret() {
  openssl rand -base64 32 | tr -d '/+=' | head -c 32
}

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: $ENV_FILE not found. Copy .env.example to .env first."
  exit 1
fi

SECRET=$(generate_secret)

sed -i '' "s|^KEYSTORE_PASS=.*|KEYSTORE_PASS=\"${SECRET}\"|" "$ENV_FILE"
sed -i '' "s|^KEY_PASS=.*|KEY_PASS=\"${SECRET}\"|" "$ENV_FILE"

echo "Generated keystore secret and wrote to $ENV_FILE"
echo "KEYSTORE_PASS and KEY_PASS set to the same random value."
echo ""
echo "If you already have a keystore.p12, you'll need to regenerate it:"
echo "  rm keystore.p12 && ./scripts/clean.sh && ./scripts/init.sh"
