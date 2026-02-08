#!/usr/bin/env bash
set -euo pipefail

# Smart notebook creation from topic research
# Usage: ./research-topic.sh "<topic>" [--depth N] [--auto-generate types] [--no-retry]

TOPIC="${1:?Usage: research-topic.sh <topic> [options]}"
shift

DEPTH=3
AUTO_GENERATE=""
NO_RETRY=false
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
    --no-retry)
      NO_RETRY=true
      shift
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
  --no-retry            Disable retry/backoff for nlm operations

Examples:
  # Basic research
  ./research-topic.sh "quantum computing"

  # Deep research with artifacts
  ./research-topic.sh "machine learning basics" --depth 10 \
    --auto-generate quiz,report
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ "$NO_RETRY" == true ]]; then
  export NLM_NO_RETRY=true
fi

NO_RETRY_FLAG=()
if [[ "$NO_RETRY" == true ]]; then
  NO_RETRY_FLAG+=(--no-retry)
fi

check_research_deps() {
  set +e
  python3 - <<'PY'
import sys
missing = []
for mod in ("requests", "ddgs"):
  try:
    __import__(mod)
  except Exception:
    missing.append(mod)
if missing:
  print("ERROR:Missing optional research dependencies: " + ", ".join(missing), file=sys.stderr)
  sys.exit(1)
PY
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "" >&2
    echo "Smart research requires optional Python dependencies." >&2
    echo "Install with:" >&2
    echo "  pip3 install -r requirements-research.txt" >&2
    echo "" >&2
    echo "If pip is blocked (externally-managed env), use a venv:" >&2
    echo "  python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements-research.txt" >&2
    exit 2
  fi
}

check_research_deps

echo "=== Smart Notebook Creation ==="
echo "Topic: $TOPIC"
echo "Depth: $DEPTH sources"
echo ""

# Step 1: Search for sources
echo "[1/3] Searching for sources..."

# Web search
echo "  Web search..."
WEB_SOURCES=$(python3 "$SCRIPT_DIR/../lib/web_search.py" "$TOPIC" "$((DEPTH / 2))")

# Wikipedia search
echo "  Wikipedia search..."
WIKI_SOURCES=$(python3 "$SCRIPT_DIR/../lib/wikipedia_search.py" "$TOPIC" 2)

# Combine sources
SOURCES_JSON=$(WEB_SOURCES_DATA="$WEB_SOURCES" WIKI_SOURCES_DATA="$WIKI_SOURCES" DEPTH_DATA="$DEPTH" python3 <<'PYEOF'
import sys, json, os

web_data = os.environ['WEB_SOURCES_DATA']
wiki_data = os.environ['WIKI_SOURCES_DATA']
depth = int(os.environ['DEPTH_DATA'])

web = json.loads(web_data)
wiki = json.loads(wiki_data)
all_sources = web + wiki

# Limit to depth before deduplication
limited = all_sources[:depth * 2]  # Get extra for dedup

print(json.dumps(limited))
PYEOF
)

# Deduplicate
echo "  Deduplicating sources..."
SOURCES_JSON=$(echo "$SOURCES_JSON" | python3 "$SCRIPT_DIR/../lib/deduplicate_sources.py" -)

# Final trim to depth
SOURCES_JSON=$(echo "$SOURCES_JSON" | NLM_DEPTH="$DEPTH" python3 -c '
import sys, json, os
sources = json.load(sys.stdin)
depth = int(os.environ["NLM_DEPTH"])
print(json.dumps(sources[:depth]))
')

SOURCE_COUNT=$(echo "$SOURCES_JSON" | python3 "$SCRIPT_DIR/../lib/json_tools.py" len)
echo "  Final: $SOURCE_COUNT unique sources"

# Step 2: Create notebook with sources
echo "[2/3] Creating notebook..."
NOTEBOOK_TITLE="Research: $TOPIC"
NOTEBOOK_ID=$("$SCRIPT_DIR/create-notebook.sh" "$NOTEBOOK_TITLE" 2>&1 | \
  python3 -c '
import sys, json
lines = sys.stdin.read()
# Find the JSON at the end
try:
    json_start = lines.rfind("{")
    if json_start != -1:
        data = json.loads(lines[json_start:])
        print(data["id"])
except Exception:
    print("", file=sys.stderr)
')

echo "  Created: $NOTEBOOK_ID"

# Add sources
echo "  Adding sources..."
SOURCE_URLS=$(echo "$SOURCES_JSON" | python3 -c '
import sys, json
sources = json.load(sys.stdin)
for s in sources:
    print(s["url"])
')

while IFS= read -r url; do
  echo "    Adding: $url"
  set +e
  "$SCRIPT_DIR/add-sources.sh" "$NOTEBOOK_ID" "${NO_RETRY_FLAG[@]}" "$url" 2>&1 | sed 's/^/      /' >&2
  ADD_RC=$?
  set -e
  if [[ $ADD_RC -ne 0 ]]; then
    echo "      (failed, continuing)" >&2
  fi
done <<< "$SOURCE_URLS"

# Step 3: Generate artifacts if requested
if [ -n "$AUTO_GENERATE" ]; then
  echo "[3/3] Generating artifacts: $AUTO_GENERATE"
  IFS=',' read -ra TYPES <<< "$AUTO_GENERATE"

  for artifact_type in "${TYPES[@]}"; do
    echo "  Generating: $artifact_type"
    set +e
    "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" --wait "${NO_RETRY_FLAG[@]}" 2>&1 | sed 's/^/    /' >&2
    GEN_RC=$?
    set -e
    if [[ $GEN_RC -ne 0 ]]; then
      echo "    (failed)" >&2
    fi
  done
else
  echo "[3/3] No artifacts requested"
fi

echo ""
echo "=== Research Complete ==="
echo "Notebook ID: $NOTEBOOK_ID"
echo "URL: https://notebooklm.google.com/notebook/$NOTEBOOK_ID"
