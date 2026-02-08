#!/usr/bin/env bash
set -euo pipefail

# Create a NotebookLM notebook
# Usage: ./create-notebook.sh <title> [--no-retry]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/retry.sh"

JSON_OUTPUT=true
QUIET=false
VERBOSE=false
NO_RETRY=false

log_info() {
  if [[ "$QUIET" != true ]]; then
    echo "$1" >&2
  fi
}

log_error() {
  echo "$1" >&2
}

debug() {
  if [[ "$VERBOSE" == true && "$QUIET" != true ]]; then
    echo "Debug: $1" >&2
  fi
}

while [[ $# -gt 0 ]]; do
  case "${1:-}" in
    --help|-h)
      cat <<EOF
Usage: create-notebook.sh <title> [options]

Creates a new NotebookLM notebook with the specified title.

Arguments:
  title    The title for the new notebook

Options:
  --json       Emit JSON result on stdout (default)
  --quiet      Suppress non-critical logs
  --verbose    Print additional diagnostics
  --no-retry   Disable retry/backoff for nlm operations
  -h, --help   Show this help message

Example:
  ./create-notebook.sh "My Research Notes"

Note: To add sources to a notebook, use add-sources.sh
EOF
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
    --no-retry)
      NO_RETRY=true
      shift
      ;;
    *)
      break
      ;;
  esac
done

if [[ "$NO_RETRY" == true ]]; then
  export NLM_NO_RETRY=true
fi

if [[ $# -lt 1 ]]; then
  cat <<EOF
Usage: create-notebook.sh <title> [options]

Creates a new NotebookLM notebook with the specified title.

Arguments:
  title    The title for the new notebook

Options:
  --json       Emit JSON result on stdout (default)
  --quiet      Suppress non-critical logs
  --verbose    Print additional diagnostics
  --no-retry    Disable retry/backoff for nlm operations
  -h, --help    Show this help message

Example:
  ./create-notebook.sh "My Research Notes"

Note: To add sources to a notebook, use add-sources.sh
EOF
  exit 1
fi

TITLE="$1"

log_info "Creating notebook: $TITLE"

# Create notebook
# Temporarily disable errexit to capture exit code correctly
set +e
NOTEBOOK_JSON=$(retry_cmd "nlm create notebook" nlm create notebook "$TITLE" 2>&1)
EXIT_CODE=$?
set -e

if [ $EXIT_CODE -ne 0 ]; then
  log_error "Error: Failed to create notebook"
  log_error "$NOTEBOOK_JSON"
  exit 1
fi

# Extract notebook ID from response
NOTEBOOK_ID=$(echo "$NOTEBOOK_JSON" | python3 -c '
import sys, json, re
output = sys.stdin.read()
# Try to parse as JSON
try:
    data = json.loads(output)
    if isinstance(data, dict) and "id" in data:
        print(data["id"])
    else:
        print("", file=sys.stderr)
except Exception:
    # Try to extract UUID from text output
    match = re.search(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", output)
    if match:
        print(match.group(0))
    else:
        print("", file=sys.stderr)
' 2>/dev/null)

if [ -z "$NOTEBOOK_ID" ]; then
  log_error "Error: Could not extract notebook ID from response:"
  log_error "$NOTEBOOK_JSON"
  exit 1
fi

log_info "✓ Created notebook: $NOTEBOOK_ID"
log_info "  Title: $TITLE"

# Output JSON result with proper escaping
if [[ "$JSON_OUTPUT" == true ]]; then
  NLM_NB_ID="$NOTEBOOK_ID" NLM_TITLE="$TITLE" python3 -c '
import json, os
print(json.dumps({
    "id": os.environ["NLM_NB_ID"],
    "title": os.environ["NLM_TITLE"],
    "sources_added": 0
}, indent=2))
'
fi
