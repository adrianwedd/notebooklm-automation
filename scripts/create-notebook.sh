#!/usr/bin/env bash
set -euo pipefail

# Create a NotebookLM notebook
# Usage: ./create-notebook.sh <title>

# Show help if requested
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  cat <<EOF
Usage: create-notebook.sh <title>

Creates a new NotebookLM notebook with the specified title.

Arguments:
  title    The title for the new notebook

Options:
  -h, --help    Show this help message

Example:
  ./create-notebook.sh "My Research Notes"

Note: To add sources to a notebook, use add-sources.sh
EOF
  exit 0
fi

TITLE="${1:?Usage: create-notebook.sh <title>}"

echo "Creating notebook: $TITLE"

# Create notebook
# Temporarily disable errexit to capture exit code correctly
set +e
NOTEBOOK_JSON=$(nlm create notebook "$TITLE" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
  echo "Error: Failed to create notebook"
  echo "$NOTEBOOK_JSON"
  exit 1
fi

# Extract notebook ID from response
NOTEBOOK_ID=$(echo "$NOTEBOOK_JSON" | python3 -c "
import sys, json, re
output = sys.stdin.read()
# Try to parse as JSON
try:
    data = json.loads(output)
    if isinstance(data, dict) and 'id' in data:
        print(data['id'])
    else:
        print('', file=sys.stderr)
except:
    # Try to extract UUID from text output
    match = re.search(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', output)
    if match:
        print(match.group(0))
    else:
        print('', file=sys.stderr)
" 2>/dev/null)

if [ -z "$NOTEBOOK_ID" ]; then
  echo "Error: Could not extract notebook ID from response:"
  echo "$NOTEBOOK_JSON"
  exit 1
fi

echo "✓ Created notebook: $NOTEBOOK_ID"
echo "  Title: $TITLE"

# Output JSON result with proper escaping
python3 -c "
import json
print(json.dumps({
    'id': '''$NOTEBOOK_ID''',
    'title': '''$TITLE''',
    'sources_added': 0
}, indent=2))
"
