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

# Parse artifact types and flags
ARTIFACT_TYPES=()
WAIT_FLAG=false
DOWNLOAD_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wait)
      WAIT_FLAG=true
      shift
      ;;
    --download)
      DOWNLOAD_DIR="$2"
      WAIT_FLAG=true
      shift 2
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

Examples:
  # Generate 3 artifacts in parallel
  ./generate-parallel.sh abc-123 audio quiz report --wait

  # Generate and download
  ./generate-parallel.sh abc-123 audio,video --download ./artifacts
EOF
      exit 0
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Parallel Artifact Generation ==="
echo "Notebook: $NOTEBOOK_ID"
echo "Artifacts: ${ARTIFACT_TYPES[*]}"
echo "Count: ${#ARTIFACT_TYPES[@]}"
echo ""

# Track background jobs
declare -a PIDS
declare -a TYPES_RUNNING
declare -a OUTPUT_FILES

# Generate artifacts in parallel
echo "Starting parallel generation..."
for artifact_type in "${ARTIFACT_TYPES[@]}"; do
  OUTPUT_FILE="/tmp/generate-${NOTEBOOK_ID}-${artifact_type}-$$.json"
  OUTPUT_FILES+=("$OUTPUT_FILE")
  TYPES_RUNNING+=("$artifact_type")

  echo "  Starting: $artifact_type"

  # Launch generate-studio.sh in background
  if [ "$WAIT_FLAG" = true ]; then
    "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" --wait \
      > "$OUTPUT_FILE" 2>&1 &
  else
    "$SCRIPT_DIR/generate-studio.sh" "$NOTEBOOK_ID" "$artifact_type" \
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

  SUCCESS_COUNT=0
  FAILED_COUNT=0

  for i in "${!PIDS[@]}"; do
    pid=${PIDS[$i]}
    artifact_type=${TYPES_RUNNING[$i]}
    output_file=${OUTPUT_FILES[$i]}

    echo "[$((i+1))/${#PIDS[@]}] Waiting for: $artifact_type (PID: $pid)"

    if wait "$pid"; then
      echo "    ✓ Completed successfully"
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
      echo "    ✗ Failed (see $output_file)"
      FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
  done

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
      ARTIFACT_ID=$(tail -5 "$output_file" | python3 -c "
import sys, json
try:
    for line in sys.stdin:
        if line.strip().startswith('{'):
            data = json.loads(line)
            print(data.get('artifact_id', 'unknown'))
            break
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

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
      nlm download "$artifact_type" "$NOTEBOOK_ID" \
        -o "$DOWNLOAD_DIR/${artifact_type}" 2>/dev/null || \
        echo "    (download not supported for $artifact_type)"
    done
  fi

  # Cleanup temp files
  for output_file in "${OUTPUT_FILES[@]}"; do
    rm -f "$output_file"
  done

  exit $FAILED_COUNT
else
  echo "Background jobs launched (not waiting)"
  echo "Job PIDs: ${PIDS[*]}"
  echo ""
  echo "Monitor with: jobs -l"
  echo "Wait for all: wait ${PIDS[*]}"
fi
