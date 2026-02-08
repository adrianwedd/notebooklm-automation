#!/usr/bin/env bash
set -euo pipefail

# Create notebook from template
# Usage: ./create-from-template.sh <template-id> [variables...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"
SCHEMA_FILE="$SCRIPT_DIR/../schemas/config.schema.json"

show_help() {
  cat <<EOF
Usage: create-from-template.sh <template-id> [--var key=value ...]

Create a NotebookLM notebook from a pre-built template.

Arguments:
  template-id    Template identifier (e.g., research/academic-paper)

Options:
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

echo "=== Creating Notebook from Template ==="
echo "Template: $TEMPLATE_ID"
echo "Variables: $VARIABLES_JSON"
echo ""

# Find template file
TEMPLATE_FILE="$TEMPLATES_DIR/${TEMPLATE_ID}.json"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Error: Template not found: $TEMPLATE_FILE"
  exit 1
fi

# Render template
echo "Rendering template..."
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

echo "Configuration:"
cat "$TEMP_CONFIG"
echo ""

# Create notebook
echo "Creating notebook..."
"$SCRIPT_DIR/automate-notebook.sh" --config "$TEMP_CONFIG"
