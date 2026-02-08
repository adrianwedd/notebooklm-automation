#!/usr/bin/env bash
# Add sources to an existing NotebookLM notebook
# Usage: add-sources.sh <notebook-id> <source1> [source2] ...
#
# Source types (auto-detected):
#   - URLs: https://... or http://...
#   - Text: text:content (prefix with "text:")
#   - Text file: textfile:/path/to/file.txt (chunks long text into multiple sources)
#   - Drive: drive://file-id (prefix with "drive://")
#   - Files: /path/to/file (local files - NOT SUPPORTED YET)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find script directory (same directory as this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/retry.sh"

# Show help
show_help() {
    cat << EOF
Usage: $(basename "$0") <notebook-id> <source1> [source2] ...

Add sources to an existing NotebookLM notebook.

Options:
  --dry-run    Print actions and exit without adding sources
  --no-retry   Disable retry/backoff for nlm operations
  --text-chunk-size <N>  Chunk long text sources into parts of ~N characters (default: 8000)
  -h, --help   Show this help message

Arguments:
  notebook-id    The ID of the notebook to add sources to
  source1...     One or more sources to add

Source types (auto-detected):
  - URLs:  https://example.com/page
  - Text:  text:Your content here
  - Text file: textfile:/path/to/file.txt
  - Drive: drive://1234567890abcdef
  - Files: /path/to/file (NOT SUPPORTED YET)

Examples:
  $(basename "$0") nb-123 https://example.com
  $(basename "$0") nb-123 "text:My notes" https://example.com
  $(basename "$0") nb-123 textfile:./notes.txt
  $(basename "$0") nb-123 drive://1abc234def

Output:
  JSON object with notebook_id, sources_added, and sources_failed

Exit codes:
  0 - All sources added successfully
  1 - One or more sources failed to add
  2 - Invalid arguments or notebook not found
EOF
}

DRY_RUN=false
NO_RETRY=false
TEXT_CHUNK_SIZE=8000

while [[ $# -gt 0 ]]; do
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-retry)
            NO_RETRY=true
            shift
            ;;
        --text-chunk-size)
            [[ -z "${2:-}" ]] && { echo "Error: --text-chunk-size requires an argument" >&2; exit 2; }
            TEXT_CHUNK_SIZE="$2"
            shift 2
            ;;
        *)
            break
            ;;
    esac
done

if [[ "$NO_RETRY" == true ]]; then
    export NLM_NO_RETRY=true
fi

if [[ ! "$TEXT_CHUNK_SIZE" =~ ^[0-9]+$ ]] || [[ "$TEXT_CHUNK_SIZE" -lt 1 ]]; then
    echo -e "${RED}Error: Invalid --text-chunk-size: $TEXT_CHUNK_SIZE (expected integer >= 1)${NC}" >&2
    exit 2
fi

count_text_chunks() {
    local text="$1"
    local chunk_size="$2"
    NLM_TEXT="$text" NLM_CHUNK="$chunk_size" python3 -c '
import math, os
text = os.environ.get("NLM_TEXT", "")
chunk = int(os.environ.get("NLM_CHUNK", "8000"))
n = max(1, math.ceil(len(text) / chunk))
print(n)
'
}

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Not enough arguments${NC}" >&2
    echo "Usage: $(basename "$0") <notebook-id> <source1> [source2] ..." >&2
    echo "Try '$(basename "$0") --help' for more information." >&2
    exit 2
fi

NOTEBOOK_ID="$1"
shift

if [[ "$DRY_RUN" == true ]]; then
    for source in "$@"; do
        if [[ "$source" =~ ^textfile: ]]; then
            path="${source#textfile:}"
            if [[ -f "$path" ]]; then
                text=$(python3 - "$path" <<'PY'
import sys
with open(sys.argv[1], "r", encoding="utf-8", errors="replace") as f:
  print(f.read())
PY
)
                n=$(count_text_chunks "$text" "$TEXT_CHUNK_SIZE")
                echo "Would add to $NOTEBOOK_ID: textfile:$path ($n chunk(s), size=$TEXT_CHUNK_SIZE)" >&2
            else
                echo "Would add to $NOTEBOOK_ID: textfile:$path (missing file)" >&2
            fi
        elif [[ "$source" =~ ^text: ]]; then
            text_content="${source#text:}"
            n=$(count_text_chunks "$text_content" "$TEXT_CHUNK_SIZE")
            if [[ "$n" -gt 1 ]]; then
                echo "Would add to $NOTEBOOK_ID: text:(chunked $n parts, size=$TEXT_CHUNK_SIZE)" >&2
            else
                echo "Would add to $NOTEBOOK_ID: $source" >&2
            fi
        else
            echo "Would add to $NOTEBOOK_ID: $source" >&2
        fi
    done
    NLM_NB_ID="$NOTEBOOK_ID" python3 -c 'import json, os; print(json.dumps({"notebook_id": os.environ["NLM_NB_ID"], "dry_run": True}))'
    exit 0
fi

# Verify notebook exists
if ! retry_cmd "nlm list sources (verify notebook)" nlm list sources "$NOTEBOOK_ID" >/dev/null; then
    echo -e "${RED}Error: Notebook '$NOTEBOOK_ID' not found${NC}" >&2
    exit 2
fi

# Counters
SOURCES_ADDED=0
SOURCES_FAILED=0

# Temporary file for collecting errors
ERROR_LOG=$(mktemp)
trap 'rm -f "$ERROR_LOG"' EXIT

emit_text_chunks_b64() {
    local label="$1"
    local text="$2"
    local chunk_size="$3"
    NLM_LABEL="$label" NLM_TEXT="$text" NLM_CHUNK="$chunk_size" python3 - <<'PY'
import base64
import os

label = os.environ.get("NLM_LABEL", "")
text = os.environ.get("NLM_TEXT", "")
chunk = int(os.environ.get("NLM_CHUNK", "8000"))
parts = [text[i:i+chunk] for i in range(0, len(text), chunk)] or [""]
n = len(parts)
for i, p in enumerate(parts, 1):
  header = f"[Part {i}/{n}]"
  if label:
    header += f" {label}"
  out = header + "\n\n" + p
  print(base64.b64encode(out.encode("utf-8")).decode("ascii"))
PY
}

emit_textfile_chunks_b64() {
    local path="$1"
    local chunk_size="$2"
    NLM_PATH="$path" NLM_CHUNK="$chunk_size" python3 - <<'PY'
import base64
import os

path = os.environ["NLM_PATH"]
chunk = int(os.environ.get("NLM_CHUNK", "8000"))

with open(path, "r", encoding="utf-8", errors="replace") as f:
  text = f.read()

label = os.path.basename(path)
parts = [text[i:i+chunk] for i in range(0, len(text), chunk)] or [""]
n = len(parts)
for i, p in enumerate(parts, 1):
  header = f"[Part {i}/{n}] {label}"
  out = header + "\n\n" + p
  print(base64.b64encode(out.encode("utf-8")).decode("ascii"))
PY
}

add_text_chunked_b64_stream() {
    local what="$1"
    local overall_rc=0
    local chunk_num=0
    local chunk_text

    while IFS= read -r b64; do
        chunk_num=$((chunk_num + 1))
        chunk_text=$(printf '%s' "$b64" | python3 -c 'import sys, base64; print(base64.b64decode(sys.stdin.read()).decode("utf-8"))')
        echo -e "${YELLOW}Adding text chunk $chunk_num:${NC} $what" >&2
        if retry_cmd "nlm add text (chunk)" nlm add text "$NOTEBOOK_ID" "$chunk_text" 2>>"$ERROR_LOG"; then
            ((SOURCES_ADDED++))
            echo -e "${GREEN}✓ Added text chunk${NC}" >&2
        else
            ((SOURCES_FAILED++))
            echo -e "${RED}✗ Failed to add text chunk${NC}" >&2
            overall_rc=1
        fi
    done

    return $overall_rc
}

# Function to detect source type and add it
add_source() {
    local source="$1"
    local result=0

    # Detect source type
    if [[ "$source" =~ ^https?:// ]]; then
        echo -e "${YELLOW}Adding URL source:${NC} $source" >&2
        if retry_cmd "nlm add url" nlm add url "$NOTEBOOK_ID" "$source" 2>>"$ERROR_LOG"; then
            ((SOURCES_ADDED++))
            echo -e "${GREEN}✓ Added URL source${NC}" >&2
        else
            ((SOURCES_FAILED++))
            echo -e "${RED}✗ Failed to add URL source${NC}" >&2
            result=1
        fi
    elif [[ "$source" =~ ^text: ]]; then
        # Remove "text:" prefix
        local text_content="${source#text:}"
        text_len=$(printf '%s' "$text_content" | wc -c | tr -d ' ')
        if [[ "$text_len" -gt "$TEXT_CHUNK_SIZE" ]]; then
            echo -e "${YELLOW}Adding long text source (chunked)${NC} (~${text_len} chars, chunk size: $TEXT_CHUNK_SIZE)" >&2
            emit_text_chunks_b64 "inline" "$text_content" "$TEXT_CHUNK_SIZE" | add_text_chunked_b64_stream "inline"
            result=$?
        else
            echo -e "${YELLOW}Adding text source${NC}" >&2
            if retry_cmd "nlm add text" nlm add text "$NOTEBOOK_ID" "$text_content" 2>>"$ERROR_LOG"; then
                ((SOURCES_ADDED++))
                echo -e "${GREEN}✓ Added text source${NC}" >&2
            else
                ((SOURCES_FAILED++))
                echo -e "${RED}✗ Failed to add text source${NC}" >&2
                result=1
            fi
        fi
    elif [[ "$source" =~ ^textfile: ]]; then
        local path="${source#textfile:}"
        if [[ ! -f "$path" ]]; then
            echo -e "${RED}Error: textfile not found:${NC} $path" >&2
            ((SOURCES_FAILED++))
            result=1
        else
            echo -e "${YELLOW}Adding text file (chunked)${NC}: $path (chunk size: $TEXT_CHUNK_SIZE)" >&2
            emit_textfile_chunks_b64 "$path" "$TEXT_CHUNK_SIZE" | add_text_chunked_b64_stream "$(basename "$path")"
            result=$?
        fi
    elif [[ "$source" =~ ^drive:// ]]; then
        # Remove "drive://" prefix
        local drive_id="${source#drive://}"
        echo -e "${YELLOW}Adding Drive source:${NC} $drive_id" >&2
        if retry_cmd "nlm add drive" nlm add drive "$NOTEBOOK_ID" "$drive_id" 2>>"$ERROR_LOG"; then
            ((SOURCES_ADDED++))
            echo -e "${GREEN}✓ Added Drive source${NC}" >&2
        else
            ((SOURCES_FAILED++))
            echo -e "${RED}✗ Failed to add Drive source${NC}" >&2
            result=1
        fi
    elif [[ -f "$source" ]]; then
        echo -e "${RED}Error: File sources not yet supported by nlm CLI${NC}" >&2
        echo -e "${YELLOW}Source:${NC} $source" >&2
        ((SOURCES_FAILED++))
        result=1
    else
        echo -e "${RED}Error: Could not detect source type for: $source${NC}" >&2
        echo -e "${YELLOW}Supported formats:${NC}" >&2
        echo "  - URLs: https://... or http://..." >&2
        echo "  - Text: text:content" >&2
        echo "  - Text file: textfile:/path/to/file.txt" >&2
        echo "  - Drive: drive://file-id" >&2
        echo "  - Files: /path/to/file (not yet supported)" >&2
        ((SOURCES_FAILED++))
        result=1
    fi

    return $result
}

# Process each source
for source in "$@"; do
    add_source "$source"
done

# Show errors if any
if [ -s "$ERROR_LOG" ]; then
    echo -e "\n${RED}Errors encountered:${NC}" >&2
    cat "$ERROR_LOG" >&2
fi

# Output JSON using Python for proper escaping
NLM_NB_ID="$NOTEBOOK_ID" NLM_ADDED="$SOURCES_ADDED" NLM_FAILED="$SOURCES_FAILED" python3 -c '
import json, os
print(json.dumps({
    "notebook_id": os.environ["NLM_NB_ID"],
    "sources_added": int(os.environ["NLM_ADDED"]),
    "sources_failed": int(os.environ["NLM_FAILED"])
}))'

# Exit with appropriate code
if [ $SOURCES_FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
