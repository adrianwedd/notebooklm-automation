#!/usr/bin/env bash
set -euo pipefail

# Create notebook from template
# Usage: ./create-from-template.sh <template-id> [variables...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

if [[ $# -lt 1 ]]; then
  echo "Usage: create-from-template.sh <template-id> [--var key=value ...]"
  echo ""
  echo "Available templates:"
  python3 "$SCRIPT_DIR/../lib/template_engine.py" list | \
    python3 -c "
import sys, json
templates = json.load(sys.stdin)
for t in templates:
    print(f\"  {t['id']:30} ({t['category']})\")
"
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
  VARIABLES_JSON=$(python3 -c "
import json
import sys
pairs = sys.argv[1:]
variables = {}
for pair in pairs:
    key, value = pair.split('=', 1)
    variables[key] = value
print(json.dumps(variables))
" "${VAR_PAIRS[@]}")
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

# Save to temp file
TEMP_CONFIG="/tmp/template-config-$$.json"
echo "$CONFIG_JSON" > "$TEMP_CONFIG"

echo "Configuration:"
cat "$TEMP_CONFIG"
echo ""

# Create notebook
echo "Creating notebook..."
"$SCRIPT_DIR/automate-notebook.sh" --config "$TEMP_CONFIG"

# Cleanup
rm -f "$TEMP_CONFIG"
