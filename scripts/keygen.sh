#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_env
ensure_dirs
cd "$DATA_DIR"

if [ ! -f config.yml ]; then
  echo "config.yml missing -- running init..."
  "$SCRIPT_DIR/init.sh"
fi

KS_PATH="$(keystore_path)"

if [ -f "$KS_PATH" ]; then
  echo "WARNING: $KS_PATH already exists."
  if [ -t 0 ]; then
    read -rp "Overwrite? (y/N) " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 0
    fi
  else
    echo "Non-interactive shell -- aborting to avoid overwrite."
    exit 1
  fi
fi

echo "Generating keystore via fdroid update..."
fdroid update --create-key

echo "Keystore created at $KS_PATH."
