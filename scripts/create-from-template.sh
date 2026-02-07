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

# Parse variables
declare -A VARIABLES
while [[ $# -gt 0 ]]; do
  case "$1" in
    --var)
      # Parse key=value
      if [[ "$2" =~ ^([^=]+)=(.+)$ ]]; then
        key="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]}"
        VARIABLES[$key]="$value"
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

# Build variables JSON
VARIABLES_JSON="{"
first=true
for key in "${!VARIABLES[@]}"; do
  if [ "$first" = false ]; then
    VARIABLES_JSON+=","
  fi
  first=false
  VARIABLES_JSON+="\"$key\":\"${VARIABLES[$key]}\""
done
VARIABLES_JSON+="}"

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
