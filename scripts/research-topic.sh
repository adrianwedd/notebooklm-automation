#!/usr/bin/env bash
set -euo pipefail

# Smart notebook creation from topic research
# Usage: ./research-topic.sh "<topic>" [--depth N] [--auto-generate types]

TOPIC="${1:?Usage: research-topic.sh <topic> [options]}"
shift

DEPTH=3
AUTO_GENERATE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    --depth)
      DEPTH="$2"
      shift 2
      ;;
    --auto-generate)
      AUTO_GENERATE="$2"
      shift 2
      ;;
    --help)
      cat <<EOF
Usage: research-topic.sh <topic> [options]

Automatically create a research notebook on a topic.

Arguments:
  topic          Topic to research (e.g., "quantum computing")

Options:
  --depth <N>           Number of sources to find (default: 3)
  --auto-generate <types>  Comma-separated artifact types to generate

Examples:
  # Basic research
  ./research-topic.sh "quantum computing"

  # Deep research with artifacts
  ./research-topic.sh "machine learning basics" --depth 10 \
    --auto-generate quiz,summary
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "=== Smart Notebook Creation ==="
echo "Topic: $TOPIC"
echo "Depth: $DEPTH sources"
echo ""

# Step 1: Search for sources
echo "[1/3] Searching for sources..."
SOURCES_JSON=$(python3 "$SCRIPT_DIR/../lib/web_search.py" "$TOPIC" "$DEPTH")
SOURCE_COUNT=$(echo "$SOURCES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

echo "  Found: $SOURCE_COUNT sources"

# Step 2: Create notebook with sources
echo "[2/3] Creating notebook..."
NOTEBOOK_TITLE="Research: $TOPIC"
NOTEBOOK_ID=$("$SCRIPT_DIR/create-notebook.sh" "$NOTEBOOK_TITLE" 2>&1 | \
  python3 -c "
import sys, json
lines = sys.stdin.read()
# Find the JSON at the end
try:
    # Split lines and get the last JSON block
    json_start = lines.rfind('{')
    if json_start != -1:
        data = json.loads(lines[json_start:])
        print(data['id'])
except Exception as e:
    print('', file=sys.stderr)
")

echo "  Created: $NOTEBOOK_ID"

# Add sources
echo "  Adding sources..."
SOURCE_URLS=$(echo "$SOURCES_JSON" | python3 -c "
import sys, json
sources = json.load(sys.stdin)
for s in sources:
    print(s['url'])
")

while IFS= read -r url; do
  echo "    Adding: $url"
  "$SCRIPT_DIR/add-sources.sh" "$NOTEBOOK_ID" "$url" > /dev/null 2>&1 || \
    echo "      (failed, continuing)"
done <<< "$SOURCE_URLS"

# Step 3: Generate artifacts if requested
if [ -n "$AUTO_GENERATE" ]; then
  echo "[3/3] Generating artifacts: $AUTO_GENERATE"
  IFS=',' read -ra TYPES <<< "$AUTO_GENERATE"

  for artifact_type in "${TYPES[@]}"; do
    echo "  Generating: $artifact_type"
    "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" --wait \
      > /dev/null 2>&1 || echo "    (failed)"
  done
else
  echo "[3/3] No artifacts requested"
fi

echo ""
echo "=== Research Complete ==="
echo "Notebook ID: $NOTEBOOK_ID"
echo "URL: https://notebooklm.google.com/notebook/$NOTEBOOK_ID"
