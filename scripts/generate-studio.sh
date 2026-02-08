#!/usr/bin/env bash
#
# generate-studio.sh - Generate NotebookLM Studio artifacts with polling support
#
# Usage:
#   generate-studio.sh <notebook-id> <type> [--wait] [--download <path>] [--description <desc>]
#
# Arguments:
#   notebook-id    Notebook ID to generate artifact for
#   type           Artifact type: audio, video, report, quiz, flashcards, mindmap, slides, infographic, data-table
#
# Options:
#   --wait                  Poll until artifact generation completes (checks every 5s, timeout 5min)
#   --download <path>       Download artifact to specified path (implies --wait)
#   --description <desc>    Description for data-table (required for data-table type)
#   --dry-run               Print planned action and exit without creating artifacts
#   --help                  Show this help message
#
# Output:
#   JSON object with: notebook_id, artifact_type, artifact_id, status
#
# Examples:
#   # Generate quiz and exit immediately
#   ./generate-studio.sh abc123 quiz
#
#   # Generate audio and wait for completion
#   ./generate-studio.sh abc123 audio --wait
#
#   # Generate audio, wait, and download
#   ./generate-studio.sh abc123 audio --download ./artifacts/podcast.mp3
#
#   # Generate data table with description
#   ./generate-studio.sh abc123 data-table --description "Compare prices by region" --wait
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error handling
error() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${GREEN}$1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}$1${NC}" >&2
}

# Show help
show_help() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \?//'
    exit 0
}

# Parse arguments
NOTEBOOK_ID=""
ARTIFACT_TYPE=""
WAIT_FLAG=false
DOWNLOAD_PATH=""
DESCRIPTION=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            ;;
        --wait)
            WAIT_FLAG=true
            shift
            ;;
        --download)
            [[ -z "${2:-}" ]] && error "--download requires an argument"
            DOWNLOAD_PATH="$2"
            WAIT_FLAG=true  # Download implies wait
            shift 2
            ;;
        --description)
            [[ -z "${2:-}" ]] && error "--description requires an argument"
            DESCRIPTION="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -*)
            error "Unknown option: $1"
            ;;
        *)
            if [[ -z "$NOTEBOOK_ID" ]]; then
                NOTEBOOK_ID="$1"
            elif [[ -z "$ARTIFACT_TYPE" ]]; then
                ARTIFACT_TYPE="$1"
            else
                error "Unexpected argument: $1"
            fi
            shift
            ;;
    esac
done

# Validate required arguments
[[ -z "$NOTEBOOK_ID" ]] && error "Missing required argument: notebook-id"
[[ -z "$ARTIFACT_TYPE" ]] && error "Missing required argument: type"

# Validate artifact type
case "$ARTIFACT_TYPE" in
    audio|video|report|quiz|flashcards|mindmap|slides|infographic|data-table)
        ;;
    *)
        error "Invalid artifact type: $ARTIFACT_TYPE. Valid types: audio video report quiz flashcards mindmap slides infographic data-table"
        ;;
esac

# Validate data-table requires description
if [[ "$ARTIFACT_TYPE" == "data-table" && -z "$DESCRIPTION" ]]; then
    error "data-table type requires --description argument"
fi

if [[ "$DRY_RUN" == true ]]; then
    if [[ "$ARTIFACT_TYPE" == "data-table" ]]; then
        info "Dry-run: would create $ARTIFACT_TYPE artifact for notebook $NOTEBOOK_ID with description: $DESCRIPTION"
    else
        info "Dry-run: would create $ARTIFACT_TYPE artifact for notebook $NOTEBOOK_ID"
    fi
    NLM_NB_ID="$NOTEBOOK_ID" NLM_ATYPE="$ARTIFACT_TYPE" python3 -c 'import json, os; print(json.dumps({"notebook_id": os.environ["NLM_NB_ID"], "artifact_type": os.environ["NLM_ATYPE"], "dry_run": True}))'
    exit 0
fi

# Create artifact using nlm CLI
info "Creating $ARTIFACT_TYPE artifact for notebook $NOTEBOOK_ID..."

case "$ARTIFACT_TYPE" in
    audio)
        nlm audio create "$NOTEBOOK_ID" -y >/dev/null 2>&1 || error "Failed to create audio artifact"
        ;;
    video)
        nlm video create "$NOTEBOOK_ID" -y >/dev/null 2>&1 || error "Failed to create video artifact"
        ;;
    report)
        nlm report create "$NOTEBOOK_ID" -y >/dev/null 2>&1 || error "Failed to create report artifact"
        ;;
    quiz)
        nlm quiz create "$NOTEBOOK_ID" -y >/dev/null 2>&1 || error "Failed to create quiz artifact"
        ;;
    flashcards)
        nlm flashcards create "$NOTEBOOK_ID" -y >/dev/null 2>&1 || error "Failed to create flashcards artifact"
        ;;
    mindmap)
        nlm mindmap create "$NOTEBOOK_ID" -y >/dev/null 2>&1 || error "Failed to create mindmap artifact"
        ;;
    slides)
        nlm slides create "$NOTEBOOK_ID" -y >/dev/null 2>&1 || error "Failed to create slides artifact"
        ;;
    infographic)
        nlm infographic create "$NOTEBOOK_ID" -y >/dev/null 2>&1 || error "Failed to create infographic artifact"
        ;;
    data-table)
        nlm data-table create "$NOTEBOOK_ID" "$DESCRIPTION" -y >/dev/null 2>&1 || error "Failed to create data-table artifact"
        ;;
esac

info "Artifact creation initiated"

# Function to check artifact status and extract artifact ID
check_status() {
    local notebook_id="$1"
    local artifact_type="$2"

    # Get status as JSON
    local status_output
    status_output=$(nlm status artifacts "$notebook_id" --json 2>/dev/null) || return 1

    # Use Python to parse JSON and find matching artifact (pass via stdin)
    echo "$status_output" | NLM_ARTIFACT_TYPE="$artifact_type" python3 -c '
import json
import sys
import os

try:
    data = json.load(sys.stdin)

    # Ensure we have an array
    if not isinstance(data, list):
        sys.exit(1)

    # Map artifact type to JSON type field value
    type_map = {
        "audio": "audio_overview",
        "video": "video_overview",
        "report": "report",
        "quiz": "quiz",
        "flashcards": "flashcards",
        "mindmap": "mindmap",
        "slides": "slides",
        "infographic": "infographic",
        "data-table": "data_table"
    }

    target_type = type_map.get(os.environ["NLM_ARTIFACT_TYPE"])
    if not target_type:
        sys.exit(1)

    # Find artifacts matching the requested type
    matching_artifacts = [a for a in data if a.get("type") == target_type]

    if not matching_artifacts:
        sys.exit(1)

    # Get the most recent artifact (last in list)
    artifact = matching_artifacts[-1]

    # Extract ID and status
    artifact_id = artifact.get("id", "")
    status = artifact.get("status", "")

    # Output: artifact_id|status
    print(f"{artifact_id}|{status}")
    sys.exit(0)

except Exception:
    sys.exit(1)
'
}

# If not waiting, just output the initial status
if [[ "$WAIT_FLAG" == false ]]; then
    sleep 2  # Brief pause to let artifact appear in status

    result=$(check_status "$NOTEBOOK_ID" "$ARTIFACT_TYPE") || {
        warn "Could not retrieve artifact status immediately"
        NLM_NB_ID="$NOTEBOOK_ID" NLM_ATYPE="$ARTIFACT_TYPE" python3 -c 'import json, os; print(json.dumps({"notebook_id": os.environ["NLM_NB_ID"], "artifact_type": os.environ["NLM_ATYPE"], "artifact_id": None, "status": "initiated"}))'
        exit 0
    }

    IFS='|' read -r artifact_id status <<< "$result"

    NLM_NB_ID="$NOTEBOOK_ID" NLM_ATYPE="$ARTIFACT_TYPE" NLM_AID="$artifact_id" NLM_STATUS="$status" python3 -c 'import json, os; print(json.dumps({"notebook_id": os.environ["NLM_NB_ID"], "artifact_type": os.environ["NLM_ATYPE"], "artifact_id": os.environ["NLM_AID"], "status": os.environ["NLM_STATUS"]}))'
    exit 0
fi

# Polling logic
info "Waiting for artifact generation to complete..."
MAX_ATTEMPTS=60  # 5 minutes with 5s intervals
ATTEMPT=0
ARTIFACT_ID=""
STATUS=""

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))

    result=$(check_status "$NOTEBOOK_ID" "$ARTIFACT_TYPE") || {
        warn "Attempt $ATTEMPT: Could not retrieve status, retrying..."
        continue
    }

    IFS='|' read -r ARTIFACT_ID STATUS <<< "$result"

    info "Attempt $ATTEMPT: Status = $STATUS"

    # Check if completed
    if [[ "$STATUS" == "completed" ]]; then
        info "Artifact generation completed!"
        break
    fi

    # Check if failed
    if [[ "$STATUS" == "failed" || "$STATUS" == "error" ]]; then
        error "Artifact generation failed with status: $STATUS"
    fi
done

# Check if we timed out
if [[ $ATTEMPT -ge $MAX_ATTEMPTS ]]; then
    warn "Timeout: Artifact generation did not complete within 5 minutes"
    NLM_NB_ID="$NOTEBOOK_ID" NLM_ATYPE="$ARTIFACT_TYPE" NLM_AID="$ARTIFACT_ID" NLM_STATUS="$STATUS" python3 -c 'import json, os; print(json.dumps({"notebook_id": os.environ["NLM_NB_ID"], "artifact_type": os.environ["NLM_ATYPE"], "artifact_id": os.environ["NLM_AID"], "status": os.environ["NLM_STATUS"]}))'
    exit 1
fi

# Download if requested
if [[ -n "$DOWNLOAD_PATH" ]]; then
    info "Attempting to download artifact to $DOWNLOAD_PATH..."

    # Try to download using nlm CLI
    case "$ARTIFACT_TYPE" in
        audio)
            if nlm download audio "$NOTEBOOK_ID" -o "$DOWNLOAD_PATH" 2>/dev/null; then
                info "Download successful: $DOWNLOAD_PATH"
            else
                warn "Download command not supported for $ARTIFACT_TYPE (nlm CLI limitation)"
            fi
            ;;
        video)
            if nlm download video "$NOTEBOOK_ID" -o "$DOWNLOAD_PATH" 2>/dev/null; then
                info "Download successful: $DOWNLOAD_PATH"
            else
                warn "Download command not supported for $ARTIFACT_TYPE (nlm CLI limitation)"
            fi
            ;;
        *)
            warn "Download not supported for artifact type: $ARTIFACT_TYPE"
            ;;
    esac
fi

# Output final JSON
NLM_NB_ID="$NOTEBOOK_ID" NLM_ATYPE="$ARTIFACT_TYPE" NLM_AID="$ARTIFACT_ID" NLM_STATUS="$STATUS" python3 -c 'import json, os; print(json.dumps({"notebook_id": os.environ["NLM_NB_ID"], "artifact_type": os.environ["NLM_ATYPE"], "artifact_id": os.environ["NLM_AID"], "status": os.environ["NLM_STATUS"]}))'
