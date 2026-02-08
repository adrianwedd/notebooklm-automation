#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS="$ROOT_DIR/lib/json_tools.py"

out_len="$(printf '[1,2,3]' | python3 "$TOOLS" len)"
if [[ "$out_len" != "3" ]]; then
  echo "expected len=3, got: $out_len" >&2
  exit 1
fi

out_get="$(printf '{\"a\":{\"b\":[{\"id\":\"x\"}]}}' | python3 "$TOOLS" get a.b.0.id)"
if [[ "$out_get" != "x" ]]; then
  echo "expected get=a.b.0.id to be x, got: $out_get" >&2
  exit 1
fi

out_tpl="$(printf '[{\"id\":\"research/academic-paper\",\"category\":\"research\"}]' | python3 "$TOOLS" print-templates)"
printf '%s\n' "$out_tpl" | grep -q "research/academic-paper" || {
  echo "expected print-templates to include template id" >&2
  exit 1
}

echo "json tools tests: ok"

