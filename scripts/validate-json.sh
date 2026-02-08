#!/usr/bin/env bash
set -euo pipefail

# Validate a JSON file against a JSON Schema.
#
# Requires: python3 + jsonschema (pip install jsonschema)

show_help() {
  cat <<EOF
Usage: validate-json.sh --schema <schema.json> --file <input.json>

Validate a JSON file against a JSON Schema. Prints validation errors to stderr.

Options:
  --json           Emit JSON summary on stdout (default)
  --quiet          Suppress non-critical logs
  --verbose        Print additional diagnostics
  --schema <path>   Path to JSON Schema file
  --file <path>     Path to JSON file to validate
  -h, --help        Show this help message

Examples:
  ./scripts/validate-json.sh --schema schemas/config.schema.json --file my-config.json
  ./scripts/validate-json.sh --schema schemas/template.schema.json --file templates/research/academic-paper.json
EOF
}

SCHEMA=""
FILE=""
JSON_OUTPUT=true
QUIET=false
VERBOSE=false

debug() {
  if [[ "$VERBOSE" == true && "$QUIET" != true ]]; then
    echo "Debug: $1" >&2
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      exit 0
      ;;
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --quiet)
      QUIET=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --schema)
      [[ -z "${2:-}" ]] && { echo "Error: --schema requires an argument" >&2; exit 2; }
      SCHEMA="$2"
      shift 2
      ;;
    --file)
      [[ -z "${2:-}" ]] && { echo "Error: --file requires an argument" >&2; exit 2; }
      FILE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

[[ -z "$SCHEMA" ]] && { echo "Error: --schema is required" >&2; exit 2; }
[[ -z "$FILE" ]] && { echo "Error: --file is required" >&2; exit 2; }
[[ ! -f "$SCHEMA" ]] && { echo "Error: schema not found: $SCHEMA" >&2; exit 2; }
[[ ! -f "$FILE" ]] && { echo "Error: file not found: $FILE" >&2; exit 2; }

NLM_QUIET="$QUIET" python3 - "$SCHEMA" "$FILE" <<'PY'
import json
import os
import sys

try:
    import jsonschema
except Exception:
    if os.environ.get("NLM_QUIET", "false") != "true":
        print("Error: missing python dependency 'jsonschema'. Install: python3 -m pip install jsonschema", file=sys.stderr)
    sys.exit(2)

schema_path = sys.argv[1]
file_path = sys.argv[2]

with open(schema_path, "r", encoding="utf-8") as f:
    schema = json.load(f)
with open(file_path, "r", encoding="utf-8") as f:
    data = json.load(f)

base_uri = os.path.abspath(schema_path)
resolver = jsonschema.RefResolver(base_uri=f"file://{base_uri}", referrer=schema)

try:
    jsonschema.validate(instance=data, schema=schema, resolver=resolver)
except jsonschema.ValidationError as e:
    print(f"Schema validation failed for {file_path}:", file=sys.stderr)
    print(e.message, file=sys.stderr)
    # Show JSON pointer-ish path for faster debugging
    if e.path:
        print("At:", "/".join(str(p) for p in e.path), file=sys.stderr)
    sys.exit(1)
PY

if [[ "$JSON_OUTPUT" == true ]]; then
  NLM_SCHEMA="$SCHEMA" NLM_FILE="$FILE" python3 -c '
import json, os
print(json.dumps({"ok": True, "schema": os.environ["NLM_SCHEMA"], "file": os.environ["NLM_FILE"]}))'
else
  if [[ "$QUIET" != true ]]; then
    echo "ok" >&2
  fi
fi
