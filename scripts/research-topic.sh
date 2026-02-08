#!/usr/bin/env bash
set -euo pipefail

# Smart notebook creation from topic research
# Usage: ./research-topic.sh "<topic>" [--depth N] [--auto-generate types] [--no-retry]

DEPTH=3
AUTO_GENERATE=""
NO_RETRY=false
JSON_OUTPUT=true
QUIET=false
VERBOSE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
Usage: research-topic.sh <topic> [options]

Automatically create a research notebook on a topic.

Arguments:
  topic          Topic to research (e.g., "quantum computing")

Options:
  --json                Emit JSON summary on stdout (default)
  --quiet               Suppress non-critical logs
  --verbose             Print additional diagnostics
  --depth <N>           Number of sources to find (default: 3)
  --auto-generate <types>  Comma-separated artifact types to generate
  --no-retry            Disable retry/backoff for nlm operations
  -h, --help             Show this help message

Examples:
  # Basic research
  ./research-topic.sh "quantum computing"

  # Deep research with artifacts
  ./research-topic.sh "machine learning basics" --depth 10 \\
    --auto-generate quiz,report
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  show_help
  exit 0
fi

TOPIC="${1:?Usage: research-topic.sh <topic> [options]}"
shift

# Parse options
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
    --help|-h)
      show_help
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

log_info "=== Smart Notebook Creation ==="
log_info "Topic: $TOPIC"
log_info "Depth: $DEPTH sources"
log_info ""

# Step 1: Search for sources
log_info "[1/3] Searching for sources..."

# Web search
log_info "  Web search..."
WEB_SOURCES=$(python3 "$SCRIPT_DIR/../lib/web_search.py" "$TOPIC" "$((DEPTH / 2))")

# Wikipedia search
log_info "  Wikipedia search..."
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
log_info "  Deduplicating sources..."
SOURCES_JSON=$(echo "$SOURCES_JSON" | python3 "$SCRIPT_DIR/../lib/deduplicate_sources.py" -)

# Final trim to depth
SOURCES_JSON=$(echo "$SOURCES_JSON" | NLM_DEPTH="$DEPTH" python3 -c '
import sys, json, os
sources = json.load(sys.stdin)
depth = int(os.environ["NLM_DEPTH"])
print(json.dumps(sources[:depth]))
')

SOURCE_COUNT=$(echo "$SOURCES_JSON" | python3 "$SCRIPT_DIR/../lib/json_tools.py" len)
log_info "  Final: $SOURCE_COUNT unique sources"

# Step 2: Create notebook with sources
log_info "[2/3] Creating notebook..."
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

log_info "  Created: $NOTEBOOK_ID"

# Add sources
log_info "  Adding sources..."
SOURCE_URLS=$(echo "$SOURCES_JSON" | python3 -c '
import sys, json
sources = json.load(sys.stdin)
for s in sources:
    print(s["url"])
')

while IFS= read -r url; do
  log_info "    Adding: $url"
  set +e
  "$SCRIPT_DIR/add-sources.sh" "$NOTEBOOK_ID" "${NO_RETRY_FLAG[@]}" "$url" 2>&1 | sed 's/^/      /' >&2
  ADD_RC=$?
  set -e
  if [[ $ADD_RC -ne 0 ]]; then
    log_warn "      (failed, continuing)"
  fi
done <<< "$SOURCE_URLS"

# Step 3: Generate artifacts if requested
if [ -n "$AUTO_GENERATE" ]; then
  log_info "[3/3] Generating artifacts: $AUTO_GENERATE"
  IFS=',' read -ra TYPES <<< "$AUTO_GENERATE"

  for artifact_type in "${TYPES[@]}"; do
    log_info "  Generating: $artifact_type"
    set +e
    "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" --wait "${NO_RETRY_FLAG[@]}" 2>&1 | sed 's/^/    /' >&2
    GEN_RC=$?
    set -e
    if [[ $GEN_RC -ne 0 ]]; then
      log_warn "    (failed)"
    fi
  done
else
  log_info "[3/3] No artifacts requested"
fi

log_info ""
log_info "=== Research Complete ==="
log_info "Notebook ID: $NOTEBOOK_ID"
log_info "URL: https://notebooklm.google.com/notebook/$NOTEBOOK_ID"

if [[ "$JSON_OUTPUT" == true ]]; then
  NLM_TOPIC="$TOPIC" NLM_NB_ID="$NOTEBOOK_ID" NLM_DEPTH="$DEPTH" NLM_SOURCES="$SOURCE_COUNT" NLM_AUTO="$AUTO_GENERATE" python3 -c '
import json, os
print(json.dumps({
  "topic": os.environ["NLM_TOPIC"],
  "notebook_id": os.environ["NLM_NB_ID"],
  "depth": int(os.environ["NLM_DEPTH"]),
  "sources": int(os.environ["NLM_SOURCES"]),
  "auto_generate": os.environ.get("NLM_AUTO", "")
}))'
fi
