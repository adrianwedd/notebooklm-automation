#!/usr/bin/env bash
set -euo pipefail

# Create a NotebookLM notebook with optional sources
# Usage: ./create-notebook.sh <title> [--sources file1.pdf,url1,text:content]

TITLE="${1:?Usage: create-notebook.sh <title> [--sources file1,file2,...]}"
SOURCES=""

# Parse optional --sources flag
shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sources)
      SOURCES="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "Creating notebook: $TITLE"

# Create notebook
NOTEBOOK_JSON=$(nlm create notebook "$TITLE" 2>&1)
if [ $? -ne 0 ]; then
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

# Output JSON result
cat <<EOF
{
  "id": "$NOTEBOOK_ID",
  "title": "$TITLE",
  "sources_added": 0
}
EOF
