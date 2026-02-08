#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADD_SOURCES="$ROOT_DIR/scripts/add-sources.sh"

tmpfile="$(mktemp -t nlm-textfile.XXXXXX)"
trap 'rm -f "$tmpfile"' EXIT

python3 - <<PY >"$tmpfile"
print("0123456789" * 50)
PY

out_inline="$("$ADD_SOURCES" --dry-run --text-chunk-size 10 nb-123 "text:0123456789abcdef" 2>&1)"
if ! printf '%s\n' "$out_inline" | grep -q "chunked"; then
  echo "expected inline text dry-run to mention chunking" >&2
  exit 1
fi

out_file="$("$ADD_SOURCES" --dry-run --text-chunk-size 10 nb-123 "textfile:$tmpfile" 2>&1)"
if ! printf '%s\n' "$out_file" | grep -q "textfile:.*chunk(s)"; then
  echo "expected textfile dry-run to mention chunk count" >&2
  exit 1
fi

echo "text chunking dry-run tests: ok"
