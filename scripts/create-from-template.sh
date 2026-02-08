#!/usr/bin/env bash
set -euo pipefail

# Create notebook from template
# Usage: ./create-from-template.sh <template-id> [variables...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
SCHEMA_FILE="$SCRIPT_DIR/../schemas/config.schema.json"

JSON_OUTPUT=true
QUIET=false
VERBOSE=false

log_info() {
  if [[ "$QUIET" != true ]]; then
    echo "$1" >&2
  fi
}

log_warn() {
  echo "$1" >&2
}

debug() {
  if [[ "$VERBOSE" == true && "$QUIET" != true ]]; then
    echo "Debug: $1" >&2
  fi
}

show_help() {
  cat <<EOF
Usage: create-from-template.sh <template-id> [--var key=value ...]

Create a NotebookLM notebook from a pre-built template.

Arguments:
  template-id    Template identifier (e.g., research/academic-paper)

Options:
  --json             Emit JSON summary on stdout (default)
  --quiet            Suppress non-critical logs
  --verbose          Print additional diagnostics
  --var KEY=VALUE    Set a template variable (can be repeated)
  -h, --help         Show this help message

Examples:
  ./create-from-template.sh research/academic-paper --var paper_topic="quantum entanglement"
  ./create-from-template.sh learning/course-notes --var course_name="Python"
  ./create-from-template.sh content/podcast-prep --var guest_name="Feynman" --var topic="physics"

Available templates:
EOF
  python3 "$SCRIPT_DIR/../lib/template_engine.py" list | \
    python3 "$SCRIPT_DIR/../lib/json_tools.py" print-templates
  exit 0
}

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  show_help
fi

if [[ $# -lt 1 ]]; then
  echo "Usage: create-from-template.sh <template-id> [--var key=value ...]" >&2
  echo "Try '--help' for more information." >&2
  exit 1
fi

TEMPLATE_ID="$1"
shift

# Parse variables into JSON using Python
VARIABLES_JSON="{}"
VAR_PAIRS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --var)
      # Parse key=value
      if [[ "$2" =~ ^([^=]+)=(.+)$ ]]; then
        VAR_PAIRS+=("$2")
      else
        echo "Error: Invalid variable format: $2"
        echo "Expected: key=value"
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Build variables JSON using Python (avoids bash 4 associative arrays)
if [ ${#VAR_PAIRS[@]} -gt 0 ]; then
  VARIABLES_JSON=$(python3 -c '
import json
import sys
pairs = sys.argv[1:]
variables = {}
for pair in pairs:
    key, value = pair.split("=", 1)
    variables[key] = value
print(json.dumps(variables))
' "${VAR_PAIRS[@]}")
fi

log_info "=== Creating Notebook from Template ==="
log_info "Template: $TEMPLATE_ID"
log_info "Variables: $VARIABLES_JSON"
log_info ""

# Find template file
TEMPLATE_FILE="$TEMPLATES_DIR/${TEMPLATE_ID}.json"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Error: Template not found: $TEMPLATE_FILE"
  exit 1
fi

# Render template
log_info "Rendering template..."
CONFIG_JSON=$(echo "$VARIABLES_JSON" | python3 "$SCRIPT_DIR/../lib/template_engine.py" render "$TEMPLATE_FILE")

# Validate rendered config (if validator + schema are present)
if [[ -x "$SCRIPT_DIR/validate-json.sh" && -f "$SCHEMA_FILE" ]]; then
  TMP_VALIDATE=$(mktemp -t nlm-rendered.XXXXXX)
  trap 'rm -f "$TMP_VALIDATE"' EXIT
  echo "$CONFIG_JSON" > "$TMP_VALIDATE"
  set +e
  "$SCRIPT_DIR/validate-json.sh" --schema "$SCHEMA_FILE" --file "$TMP_VALIDATE" >/dev/null
  SCHEMA_EXIT=$?
  set -e
  if [[ $SCHEMA_EXIT -eq 1 ]]; then
    echo "Error: Rendered config failed schema validation" >&2
    exit 1
  elif [[ $SCHEMA_EXIT -eq 2 ]]; then
    echo "Warning: Schema validation skipped (missing python dependency 'jsonschema'). See README Schemas section." >&2
  fi
  rm -f "$TMP_VALIDATE"
  trap - EXIT
fi

# Save to temp file
TEMP_CONFIG=$(mktemp -t nlm-template.XXXXXX)
trap 'rm -f "$TEMP_CONFIG"' EXIT
echo "$CONFIG_JSON" > "$TEMP_CONFIG"

log_info "Configuration:"
cat "$TEMP_CONFIG" >&2
log_info ""

# Create notebook
log_info "Creating notebook..."
AUTOMATE_ARGS=("$SCRIPT_DIR/automate-notebook.sh" --config "$TEMP_CONFIG")
if [[ "$QUIET" == true ]]; then
  AUTOMATE_ARGS+=(--quiet)
fi
if [[ "$VERBOSE" == true ]]; then
  AUTOMATE_ARGS+=(--verbose)
fi
if [[ "$JSON_OUTPUT" == true ]]; then
  "${AUTOMATE_ARGS[@]}"
else
  "${AUTOMATE_ARGS[@]}" 1>&2
fi
