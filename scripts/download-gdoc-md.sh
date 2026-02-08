#!/usr/bin/env bash
#
# download-gdoc-md.sh - Download a Google Doc as Markdown
#
# Uses the Google Docs export API to download a document in Markdown format.
# Requires browser cookies for authentication.
#
# Usage:
#   download-gdoc-md.sh <doc_url_or_id> [--output <file>] [--cookies <file>] [--help]
#
# Arguments:
#   <doc_url_or_id>     Google Docs URL or document ID
#   --output <file>     Output file path (default: <doc_title>.md)
#   --cookies <file>    Path to cookies file (Netscape format, default: cookies.txt)
#
# Examples:
#   # Download by URL
#   ./scripts/download-gdoc-md.sh "https://docs.google.com/document/d/1abc.../edit"
#
#   # Download by ID with custom output
#   ./scripts/download-gdoc-md.sh 1abc... --output research-report.md
#
#   # Download with specific cookies file
#   ./scripts/download-gdoc-md.sh 1abc... --cookies ~/google-cookies.txt
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COOKIES_FILE="${SCRIPT_DIR}/../cookies.txt"
OUTPUT_FILE=""
DOC_INPUT=""

# --- Help ---
show_help() {
    awk 'NR>1 && /^[^#]/{exit} NR>1{print}' "$0" | sed -E 's/^# ?//'
    exit 0
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h) show_help ;;
        --output|-o) OUTPUT_FILE="$2"; shift 2 ;;
        --cookies|-c) COOKIES_FILE="$2"; shift 2 ;;
        *) DOC_INPUT="$1"; shift ;;
    esac
done

if [[ -z "$DOC_INPUT" ]]; then
    echo "Error: Document URL or ID is required" >&2
    echo "Usage: $0 <doc_url_or_id> [--output <file>] [--cookies <file>]" >&2
    exit 1
fi

# --- Extract document ID ---
extract_doc_id() {
    local input="$1"
    # Full URL: https://docs.google.com/document/d/<ID>/edit
    if [[ "$input" =~ /document/d/([a-zA-Z0-9_-]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    # Just the ID
    elif [[ "$input" =~ ^[a-zA-Z0-9_-]{20,}$ ]]; then
        echo "$input"
    else
        echo "Error: Cannot extract document ID from: $input" >&2
        return 1
    fi
}

DOC_ID=$(extract_doc_id "$DOC_INPUT")
echo "Document ID: $DOC_ID" >&2

# --- Check cookies ---
if [[ ! -f "$COOKIES_FILE" ]]; then
    echo "Error: Cookies file not found: $COOKIES_FILE" >&2
    echo "" >&2
    echo "To export cookies from Chrome:" >&2
    echo "  1. Install a cookies export extension (e.g., 'Get cookies.txt LOCALLY')" >&2
    echo "  2. Navigate to docs.google.com" >&2
    echo "  3. Export cookies in Netscape format" >&2
    echo "  4. Save to: $COOKIES_FILE" >&2
    exit 1
fi

# --- Build export URL ---
EXPORT_URL="https://docs.google.com/document/d/${DOC_ID}/export?format=md"
echo "Export URL: $EXPORT_URL" >&2

# --- Determine output filename ---
if [[ -z "$OUTPUT_FILE" ]]; then
    # Try to get the document title from the metadata
    # Fallback to doc ID as filename
    OUTPUT_FILE="${DOC_ID}.md"

    # Try to extract title from the page
    TITLE=$(curl -s -L -b "$COOKIES_FILE" \
        "https://docs.google.com/document/d/${DOC_ID}/edit" 2>/dev/null \
        | grep -oP '<title>\K[^<]+' \
        | sed 's/ - Google Docs$//' \
        | sed 's/[^a-zA-Z0-9 _-]//g' \
        | sed 's/ /-/g' \
        | head -1 || true)

    if [[ -n "$TITLE" ]]; then
        OUTPUT_FILE="${TITLE}.md"
    fi
fi

echo "Output: $OUTPUT_FILE" >&2

# --- Download ---
HTTP_CODE=$(curl -s -L -b "$COOKIES_FILE" \
    -o "$OUTPUT_FILE" \
    -w '%{http_code}' \
    "$EXPORT_URL")

if [[ "$HTTP_CODE" == "200" ]]; then
    FILE_SIZE=$(wc -c < "$OUTPUT_FILE" | tr -d ' ')
    echo "Downloaded: $OUTPUT_FILE ($FILE_SIZE bytes)" >&2
    echo "$OUTPUT_FILE"
else
    echo "Error: Download failed with HTTP $HTTP_CODE" >&2
    rm -f "$OUTPUT_FILE"
    exit 1
fi
