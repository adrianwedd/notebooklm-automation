#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"

tmpdir="$(mktemp -d -t nlm-dryrun.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

fail() { echo "dry-run smoke test failed: $*" >&2; exit 1; }

assert_json_stdout_only() {
  local name="$1"
  local stdout_file="$2"
  local stderr_file="$3"

  if [[ -s "$stderr_file" ]]; then
    echo "stderr not empty for $name:" >&2
    sed -n '1,200p' "$stderr_file" >&2
    return 1
  fi

  if [[ ! -s "$stdout_file" ]]; then
    echo "stdout empty for $name" >&2
    return 1
  fi

  python3 - "$name" "$stdout_file" <<'PY'
import json
import sys

name = sys.argv[1]
path = sys.argv[2]
raw = open(path, "r", encoding="utf-8", errors="replace").read().strip()

try:
  obj = json.loads(raw)
except Exception as e:
  print(f"{name}: stdout is not valid JSON: {e}", file=sys.stderr)
  print("stdout:", raw[:4000], file=sys.stderr)
  sys.exit(1)

if not isinstance(obj, dict):
  print(f"{name}: expected JSON object, got {type(obj).__name__}", file=sys.stderr)
  sys.exit(1)
PY
}

run_cmd() {
  local name="$1"
  shift

  local out="$tmpdir/${name}.out"
  local err="$tmpdir/${name}.err"

  set +e
  "$@" >"$out" 2>"$err"
  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    echo "command failed ($name) rc=$rc:" >&2
    printf '%q ' "$@" >&2
    echo "" >&2
    echo "stderr:" >&2
    sed -n '1,200p' "$err" >&2
    fail "$name returned non-zero"
  fi

  assert_json_stdout_only "$name" "$out" "$err" || fail "$name output contract violated"
}

run_cmd_quiet_ok() {
  local name="$1"
  shift

  local out="$tmpdir/${name}.out"
  local err="$tmpdir/${name}.err"

  set +e
  "$@" >"$out" 2>"$err"
  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    echo "command failed ($name) rc=$rc:" >&2
    printf '%q ' "$@" >&2
    echo "" >&2
    echo "stderr:" >&2
    sed -n '1,200p' "$err" >&2
    fail "$name returned non-zero"
  fi

  if [[ -s "$err" ]]; then
    echo "stderr not empty for $name:" >&2
    sed -n '1,200p' "$err" >&2
    fail "$name stderr not empty"
  fi
}

# Minimal config for automate-notebook.sh --dry-run (no nlm required).
cfg="$tmpdir/config.json"
cat >"$cfg" <<'EOF'
{
  "title": "Dry Run Smoke Test",
  "sources": [
    "https://example.com",
    "text:hello world"
  ],
  "studio": [
    {"type": "quiz"}
  ]
}
EOF

run_cmd "automate_notebook_dry_run" \
  "$SCRIPTS_DIR/automate-notebook.sh" --quiet --dry-run --config "$cfg"

run_cmd "add_sources_dry_run" \
  "$SCRIPTS_DIR/add-sources.sh" --quiet --dry-run nb-123 "https://example.com" "text:hello"

run_cmd "generate_studio_dry_run" \
  "$SCRIPTS_DIR/generate-studio.sh" --quiet --dry-run nb-123 quiz

run_cmd "generate_parallel_dry_run" \
  "$SCRIPTS_DIR/generate-parallel.sh" --quiet --dry-run nb-123 quiz,report --wait

# Validate config JSON is well-formed (no external deps).
run_cmd_quiet_ok "config_json_parse_ok" \
  python3 -c 'import json,sys; json.load(open(sys.argv[1], "r", encoding="utf-8"))' "$cfg"

echo "dry-run smoke tests: ok"
