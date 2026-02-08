#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "== nlm + /dev/null suppressions (scripts/*.sh) =="
if ! rg -n 'nlm .*dev/null|dev/null.*nlm' "$ROOT_DIR/scripts"/*.sh; then
  echo "(none)"
fi

echo ""
echo "== all /dev/null suppressions (scripts/*.sh) =="
rg -n '>/dev/null|2>/dev/null|&>/dev/null' "$ROOT_DIR/scripts"/*.sh || true

