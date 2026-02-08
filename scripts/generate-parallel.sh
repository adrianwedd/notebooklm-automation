#!/usr/bin/env bash
set -euo pipefail

# Parallel artifact generation for NotebookLM
# Usage: ./generate-parallel.sh <notebook-id> <type1> [type2] [type3] ...
#
# Examples:
#   ./generate-parallel.sh abc-123 audio quiz report
#   ./generate-parallel.sh abc-123 audio,quiz,report --wait --download ./artifacts

NOTEBOOK_ID="${1:?Usage: generate-parallel.sh <notebook-id> <types...> [--wait] [--download dir]}"
shift

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/retry.sh"

# Parse artifact types and flags
ARTIFACT_TYPES=()
WAIT_FLAG=false
DOWNLOAD_DIR=""
DRY_RUN=false
NO_RETRY=false
STUDIO_EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      WAIT_FLAG=true
      shift
      ;;
    --download)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --download requires a directory argument" >&2
        exit 1
      fi
      DOWNLOAD_DIR="$2"
      WAIT_FLAG=true
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --no-retry)
      NO_RETRY=true
      shift
      ;;
    --help)
      cat <<EOF
Usage: generate-parallel.sh <notebook-id> <types...> [options]

Generate multiple studio artifacts in parallel.

Arguments:
  notebook-id    Notebook ID
  types          Artifact types (space or comma-separated)
                 audio, video, report, quiz, flashcards, mindmap,
                 slides, infographic, data-table

Options:
  --wait              Wait for all artifacts to complete
  --download <dir>    Download all artifacts to directory (implies --wait)
  --dry-run           Print planned actions and exit without creating artifacts
  --no-retry          Disable retry/backoff for nlm operations
  -h, --help          Show this help message

Examples:
  # Generate 3 artifacts in parallel
  ./generate-parallel.sh abc-123 audio quiz report --wait

  # Generate and download
  ./generate-parallel.sh abc-123 audio,video --download ./artifacts
EOF
      exit 0
      ;;
    -h)
      # Keep help consistent across scripts.
      set -- --help
      ;;
    *)
      # Split comma-separated types
      IFS=',' read -ra TYPES <<< "$1"
      ARTIFACT_TYPES+=("${TYPES[@]}")
      shift
      ;;
  esac
done

if [ ${#ARTIFACT_TYPES[@]} -eq 0 ]; then
  echo "Error: No artifact types specified"
  exit 1
fi

if [[ "$NO_RETRY" == true ]]; then
  export NLM_NO_RETRY=true
  STUDIO_EXTRA_ARGS+=(--no-retry)
fi

if [[ "$DRY_RUN" == true ]]; then
  echo "=== Parallel Artifact Generation (dry-run) ===" >&2
  echo "Notebook: $NOTEBOOK_ID" >&2
  echo "Artifacts: ${ARTIFACT_TYPES[*]}" >&2
  echo "Wait: $WAIT_FLAG" >&2
  if [[ -n "$DOWNLOAD_DIR" ]]; then
    echo "Download dir: $DOWNLOAD_DIR" >&2
  fi
  for artifact_type in "${ARTIFACT_TYPES[@]}"; do
    if [[ "$WAIT_FLAG" == true ]]; then
      if [[ "$NO_RETRY" == true ]]; then
        echo "Would run: $SCRIPT_DIR/generate-studio.sh \"$NOTEBOOK_ID\" \"$artifact_type\" --wait --no-retry" >&2
      else
        echo "Would run: $SCRIPT_DIR/generate-studio.sh \"$NOTEBOOK_ID\" \"$artifact_type\" --wait" >&2
      fi
    else
      if [[ "$NO_RETRY" == true ]]; then
        echo "Would run: $SCRIPT_DIR/generate-studio.sh \"$NOTEBOOK_ID\" \"$artifact_type\" --no-retry" >&2
      else
        echo "Would run: $SCRIPT_DIR/generate-studio.sh \"$NOTEBOOK_ID\" \"$artifact_type\"" >&2
      fi
    fi
  done
  NLM_NB_ID="$NOTEBOOK_ID" python3 -c 'import json, os; print(json.dumps({"notebook_id": os.environ["NLM_NB_ID"], "dry_run": True}))'
  exit 0
fi

echo "=== Parallel Artifact Generation ==="
echo "Notebook: $NOTEBOOK_ID"
echo "Artifacts: ${ARTIFACT_TYPES[*]}"
echo "Count: ${#ARTIFACT_TYPES[@]}"
echo ""

# Track background jobs
declare -a PIDS
declare -a TYPES_RUNNING
declare -a OUTPUT_FILES

# Temp directory for output files
NLM_TMPDIR=$(mktemp -d -t nlm-parallel.XXXXXX)
trap 'rm -rf "$NLM_TMPDIR"' EXIT

# Progress monitoring function
monitor_progress() {
  local pids=("$@")
  local total=${#pids[@]}
  local completed=0

  while [ "$completed" -lt "$total" ]; do
    completed=0
    for pid in "${pids[@]}"; do
      if ! kill -0 "$pid" 2>/dev/null; then
        completed=$((completed + 1))
      fi
    done

    echo -ne "\rProgress: $completed/$total artifacts completed"
    sleep 2
  done

  echo "" # New line after progress
}

# Generate artifacts in parallel
echo "Starting parallel generation..."
for artifact_type in "${ARTIFACT_TYPES[@]}"; do
  OUTPUT_FILE="${NLM_TMPDIR}/generate-${artifact_type}.json"
  OUTPUT_FILES+=("$OUTPUT_FILE")
  TYPES_RUNNING+=("$artifact_type")

  echo "  Starting: $artifact_type"

  # Launch generate-studio.sh in background
  if [ "$WAIT_FLAG" = true ]; then
    "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" --wait "${STUDIO_EXTRA_ARGS[@]}" \
      > "$OUTPUT_FILE" 2>&1 &
  else
    "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" "${STUDIO_EXTRA_ARGS[@]}" \
      > "$OUTPUT_FILE" 2>&1 &
  fi

  PIDS+=($!)
done

echo ""
echo "Launched ${#PIDS[@]} parallel jobs"
echo ""

# Wait for all jobs if requested
if [ "$WAIT_FLAG" = true ]; then
  echo "Waiting for completion..."
  echo ""

  # Monitor progress in background
  monitor_progress "${PIDS[@]}" &
  MONITOR_PID=$!

  SUCCESS_COUNT=0
  FAILED_COUNT=0

  # Wait for all jobs to complete
  for pid in "${PIDS[@]}"; do
    wait "$pid" || FAILED_COUNT=$((FAILED_COUNT + 1))
  done

  # Stop progress monitor
  kill "$MONITOR_PID" 2>/dev/null || true
  wait "$MONITOR_PID" 2>/dev/null || true

  SUCCESS_COUNT=$(( ${#PIDS[@]} - FAILED_COUNT ))

  echo ""
  echo "=== Generation Complete ==="
  echo "Success: $SUCCESS_COUNT"
  echo "Failed:  $FAILED_COUNT"
  echo ""

  # Aggregate results
  echo "Results:"
  for i in "${!OUTPUT_FILES[@]}"; do
    artifact_type=${TYPES_RUNNING[$i]}
    output_file=${OUTPUT_FILES[$i]}

    if [ -f "$output_file" ]; then
      # Extract artifact_id from JSON output
      ARTIFACT_ID=$(tail -5 "$output_file" | python3 -c '
import sys, json
try:
    for line in sys.stdin:
        if line.strip().startswith("{"):
            data = json.loads(line)
            print(data.get("artifact_id", "unknown"))
            break
except Exception:
    print("unknown")
' 2>/dev/null || echo "unknown")

      echo "  $artifact_type: $ARTIFACT_ID"
    fi
  done

  # Download if requested
  if [ -n "$DOWNLOAD_DIR" ]; then
    echo ""
    echo "Downloading artifacts to: $DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"

    for artifact_type in "${TYPES_RUNNING[@]}"; do
      echo "  Downloading: $artifact_type"
      # Note: Download logic depends on nlm CLI support
      # This is a placeholder - actual download may not work for all types
      retry_cmd "nlm download $artifact_type" nlm download "$artifact_type" "$NOTEBOOK_ID" \
        -o "$DOWNLOAD_DIR/${artifact_type}" 1>/dev/null || \
        echo "    (download not supported for $artifact_type)"
    done
  fi

  exit $FAILED_COUNT
else
  echo "Background jobs launched (not waiting)"
  echo "Job PIDs: ${PIDS[*]}"
  echo ""
  echo "Monitor with: jobs -l"
  echo "Wait for all: wait ${PIDS[*]}"
fi
