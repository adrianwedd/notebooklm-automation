#!/usr/bin/env bash
# Add sources to an existing NotebookLM notebook
# Usage: add-sources.sh <notebook-id> <source1> [source2] ...
#
# Source types (auto-detected):
#   - URLs: https://... or http://...
#   - Text: text:content (prefix with "text:")
#   - Drive: drive://file-id (prefix with "drive://")
#   - Files: /path/to/file (local files - NOT SUPPORTED YET)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Show help
show_help() {
    cat << EOF
Usage: $(basename "$0") <notebook-id> <source1> [source2] ...

Add sources to an existing NotebookLM notebook.

Arguments:
  notebook-id    The ID of the notebook to add sources to
  source1...     One or more sources to add

Source types (auto-detected):
  - URLs:  https://example.com/page
  - Text:  text:Your content here
  - Drive: drive://1234567890abcdef
  - Files: /path/to/file (NOT SUPPORTED YET)

Examples:
  $(basename "$0") nb-123 https://example.com
  $(basename "$0") nb-123 "text:My notes" https://example.com
  $(basename "$0") nb-123 drive://1abc234def

Output:
  JSON object with notebook_id, sources_added, and sources_failed

Exit codes:
  0 - All sources added successfully
  1 - One or more sources failed to add
  2 - Invalid arguments or notebook not found
EOF
}

# Check for help flag
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_help
    exit 0
fi

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Not enough arguments${NC}" >&2
    echo "Usage: $(basename "$0") <notebook-id> <source1> [source2] ..." >&2
    echo "Try '$(basename "$0") --help' for more information." >&2
    exit 2
fi

NOTEBOOK_ID="$1"
shift

# Verify notebook exists
if ! nlm list sources "$NOTEBOOK_ID" &>/dev/null; then
    echo -e "${RED}Error: Notebook '$NOTEBOOK_ID' not found${NC}" >&2
    exit 2
fi

# Counters
SOURCES_ADDED=0
SOURCES_FAILED=0

# Temporary file for collecting errors
ERROR_LOG=$(mktemp)
trap "rm -f $ERROR_LOG" EXIT

# Function to detect source type and add it
add_source() {
    local source="$1"
    local source_type=""
    local result=0

    # Detect source type
    if [[ "$source" =~ ^https?:// ]]; then
        source_type="url"
        echo -e "${YELLOW}Adding URL source:${NC} $source" >&2
        if nlm add url "$NOTEBOOK_ID" "$source" 2>>"$ERROR_LOG"; then
            ((SOURCES_ADDED++))
            echo -e "${GREEN}✓ Added URL source${NC}" >&2
        else
            ((SOURCES_FAILED++))
            echo -e "${RED}✗ Failed to add URL source${NC}" >&2
            result=1
        fi
    elif [[ "$source" =~ ^text: ]]; then
        source_type="text"
        # Remove "text:" prefix
        local text_content="${source#text:}"
        echo -e "${YELLOW}Adding text source${NC}" >&2
        if nlm add text "$NOTEBOOK_ID" "$text_content" 2>>"$ERROR_LOG"; then
            ((SOURCES_ADDED++))
            echo -e "${GREEN}✓ Added text source${NC}" >&2
        else
            ((SOURCES_FAILED++))
            echo -e "${RED}✗ Failed to add text source${NC}" >&2
            result=1
        fi
    elif [[ "$source" =~ ^drive:// ]]; then
        source_type="drive"
        # Remove "drive://" prefix
        local drive_id="${source#drive://}"
        echo -e "${YELLOW}Adding Drive source:${NC} $drive_id" >&2
        if nlm add drive "$NOTEBOOK_ID" "$drive_id" 2>>"$ERROR_LOG"; then
            ((SOURCES_ADDED++))
            echo -e "${GREEN}✓ Added Drive source${NC}" >&2
        else
            ((SOURCES_FAILED++))
            echo -e "${RED}✗ Failed to add Drive source${NC}" >&2
            result=1
        fi
    elif [[ -f "$source" ]]; then
        source_type="file"
        echo -e "${RED}Error: File sources not yet supported by nlm CLI${NC}" >&2
        echo -e "${YELLOW}Source:${NC} $source" >&2
        ((SOURCES_FAILED++))
        result=1
    else
        echo -e "${RED}Error: Could not detect source type for: $source${NC}" >&2
        echo -e "${YELLOW}Supported formats:${NC}" >&2
        echo "  - URLs: https://... or http://..." >&2
        echo "  - Text: text:content" >&2
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
python3 -c "import json; print(json.dumps({
    'notebook_id': '$NOTEBOOK_ID',
    'sources_added': $SOURCES_ADDED,
    'sources_failed': $SOURCES_FAILED
}))"

# Exit with appropriate code
if [ $SOURCES_FAILED -gt 0 ]; then
    exit 1
else
    exit 0
fi
