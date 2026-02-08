#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

tmpdir="$(mktemp -d -t nlm-template-test.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

fail() { echo "template engine test failed: $*" >&2; exit 1; }

tmpl="$tmpdir/t.json"
cat >"$tmpl" <<'EOF'
{
  "title": "Hello {{name}}",
  "smart_creation": {
    "enabled": true,
    "topic": "{{topic}}"
  }
}
EOF

# Missing vars should fail with a clear message.
set +e
err="$tmpdir/err"
python3 "$ROOT_DIR/lib/template_engine.py" render "$tmpl" >"$tmpdir/out" 2>"$err"
rc=$?
set -e
[[ $rc -ne 0 ]] || fail "expected non-zero exit for missing vars"
grep -Eq "Missing template variables: (name, topic|topic, name)" "$err" || fail "missing vars message not found"

# Providing vars should succeed and leave no placeholders.
vars="$tmpdir/vars.json"
cat >"$vars" <<'EOF'
{"name":"World","topic":"test"}
EOF
python3 "$ROOT_DIR/lib/template_engine.py" render "$tmpl" "$vars" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["title"]=="Hello World"; assert d["smart_creation"]["topic"]=="test"'

# --allow-unresolved should permit missing variables.
python3 "$ROOT_DIR/lib/template_engine.py" render "$tmpl" --allow-unresolved | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "{{name}}" in d["title"]'

echo "template engine tests: ok"
