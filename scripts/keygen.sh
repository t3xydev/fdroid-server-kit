#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# -- Generate configs if missing -----------------------------------------------

if [ ! -f config.yml ]; then
  echo "config.yml missing -- running init..."
  "$SCRIPT_DIR/init.sh"
fi

# -- Guard: check signing is enabled ------------------------------------------

ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
if [ -f "$ENV_FILE" ]; then
  REPO_SIGNED=$(grep -E '^REPO_SIGNED=' "$ENV_FILE" | cut -d= -f2 | tr -d '"' || echo "true")
fi

if [ "${REPO_SIGNED:-true}" != "true" ]; then
  echo "ERROR: REPO_SIGNED is set to false -- keystore generation requires signing to be enabled."
  exit 1
fi

# -- Guard: don't overwrite existing keystore ----------------------------------

KEYSTORE_FILE=$(grep -E '^KEYSTORE_FILE=' "$ENV_FILE" | cut -d= -f2 | tr -d '"' || echo "keystore.p12")

if [ -f "$ROOT_DIR/${KEYSTORE_FILE:-keystore.p12}" ]; then
  echo "WARNING: ${KEYSTORE_FILE:-keystore.p12} already exists."
  read -rp "Overwrite? (y/N) " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# -- Generate keystore ---------------------------------------------------------

echo "Generating keystore via fdroid update..."
fdroid update --create-key

echo "Keystore created. You can now run ./scripts/build.sh or ./scripts/publish.sh."
