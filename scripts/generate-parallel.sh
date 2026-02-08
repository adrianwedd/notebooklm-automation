#!/usr/bin/env bash
set -euo pipefail

# Parallel artifact generation for NotebookLM
# Usage: ./generate-parallel.sh <notebook-id> <type1> [type2] [type3] ...
#
# Examples:
#   ./generate-parallel.sh abc-123 audio quiz report
#   ./generate-parallel.sh abc-123 audio,quiz,report --wait --download ./artifacts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/retry.sh"

JSON_OUTPUT=true
QUIET=false
# shellcheck disable=SC2034
VERBOSE=false

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
Usage: generate-parallel.sh <notebook-id> <types...> [options]

Generate multiple studio artifacts in parallel.

Arguments:
  notebook-id    Notebook ID
  types          Artifact types (space or comma-separated)
                 audio, video, report, quiz, flashcards, mindmap,
                 slides, infographic, data-table

Options:
  --json              Emit JSON summary on stdout (default)
  --quiet             Suppress non-critical logs
  --verbose           Print additional diagnostics
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
}

# Parse arguments (options can appear before/after positional args).
NOTEBOOK_ID=""
ARTIFACT_TYPES=()
WAIT_FLAG=false
DOWNLOAD_DIR=""
DRY_RUN=false
NO_RETRY=false
STUDIO_EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      show_help
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
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$NOTEBOOK_ID" ]]; then
        NOTEBOOK_ID="$1"
      else
        # Split comma-separated types
        IFS=',' read -ra TYPES <<< "$1"
        ARTIFACT_TYPES+=("${TYPES[@]}")
      fi
      shift
      ;;
  esac
done

if [[ -z "$NOTEBOOK_ID" ]]; then
  echo "Error: Missing required argument: notebook-id" >&2
  echo "Try --help for usage." >&2
  exit 1
fi

if [ ${#ARTIFACT_TYPES[@]} -eq 0 ]; then
  echo "Error: No artifact types specified"
  exit 1
fi

if [[ "$NO_RETRY" == true ]]; then
  export NLM_NO_RETRY=true
  STUDIO_EXTRA_ARGS+=(--no-retry)
fi

if [[ "$DRY_RUN" == true ]]; then
  log_info "=== Parallel Artifact Generation (dry-run) ==="
  log_info "Notebook: $NOTEBOOK_ID"
  log_info "Artifacts: ${ARTIFACT_TYPES[*]}"
  log_info "Wait: $WAIT_FLAG"
  if [[ -n "$DOWNLOAD_DIR" ]]; then
    log_info "Download dir: $DOWNLOAD_DIR"
  fi
  for artifact_type in "${ARTIFACT_TYPES[@]}"; do
    if [[ "$WAIT_FLAG" == true ]]; then
      if [[ "$NO_RETRY" == true ]]; then
        log_info "Would run: $SCRIPT_DIR/generate-studio.sh \"$NOTEBOOK_ID\" \"$artifact_type\" --wait --no-retry"
      else
        log_info "Would run: $SCRIPT_DIR/generate-studio.sh \"$NOTEBOOK_ID\" \"$artifact_type\" --wait"
      fi
    else
      if [[ "$NO_RETRY" == true ]]; then
        log_info "Would run: $SCRIPT_DIR/generate-studio.sh \"$NOTEBOOK_ID\" \"$artifact_type\" --no-retry"
      else
        log_info "Would run: $SCRIPT_DIR/generate-studio.sh \"$NOTEBOOK_ID\" \"$artifact_type\""
      fi
    fi
  done
  if [[ "$JSON_OUTPUT" == true ]]; then
    NLM_NB_ID="$NOTEBOOK_ID" python3 -c 'import json, os; print(json.dumps({"notebook_id": os.environ["NLM_NB_ID"], "dry_run": True}))'
  fi
  exit 0
fi

log_info "=== Parallel Artifact Generation ==="
log_info "Notebook: $NOTEBOOK_ID"
log_info "Artifacts: ${ARTIFACT_TYPES[*]}"
log_info "Count: ${#ARTIFACT_TYPES[@]}"
log_info ""

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

    if [[ "$QUIET" != true ]]; then
      echo -ne "\rProgress: $completed/$total artifacts completed" >&2
    fi
    sleep 2
  done

  echo "" >&2 # New line after progress
}

# Generate artifacts in parallel
log_info "Starting parallel generation..."
for artifact_type in "${ARTIFACT_TYPES[@]}"; do
  OUTPUT_FILE="${NLM_TMPDIR}/generate-${artifact_type}.json"
  OUTPUT_FILES+=("$OUTPUT_FILE")
  TYPES_RUNNING+=("$artifact_type")

  log_info "  Starting: $artifact_type"

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

log_info ""
log_info "Launched ${#PIDS[@]} parallel jobs"
log_info ""

# Wait for all jobs if requested
if [ "$WAIT_FLAG" = true ]; then
  log_info "Waiting for completion..."
  log_info ""

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

  log_info ""
  log_info "=== Generation Complete ==="
  log_info "Success: $SUCCESS_COUNT"
  log_info "Failed:  $FAILED_COUNT"
  log_info ""

  # Aggregate results
  RESULTS_TMP=$(mktemp -t nlm-parallel-results.XXXXXX)
  trap 'rm -rf "$NLM_TMPDIR"; rm -f "$RESULTS_TMP"' EXIT
  : >"$RESULTS_TMP"

  log_info "Results:"
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
      echo "${artifact_type}|${ARTIFACT_ID}" >>"$RESULTS_TMP"
    fi
  done

  # Download if requested
  if [ -n "$DOWNLOAD_DIR" ]; then
    log_info ""
    log_info "Downloading artifacts to: $DOWNLOAD_DIR"
    mkdir -p "$DOWNLOAD_DIR"

    for artifact_type in "${TYPES_RUNNING[@]}"; do
      log_info "  Downloading: $artifact_type"
      # Note: Download logic depends on nlm CLI support
      # This is a placeholder - actual download may not work for all types
      retry_cmd "nlm download $artifact_type" nlm download "$artifact_type" "$NOTEBOOK_ID" \
        -o "$DOWNLOAD_DIR/${artifact_type}" 1>/dev/null || \
        log_warn "    (download not supported for $artifact_type)"
    done
  fi

  if [[ "$JSON_OUTPUT" == true ]]; then
    NLM_NB_ID="$NOTEBOOK_ID" NLM_OK="$SUCCESS_COUNT" NLM_FAIL="$FAILED_COUNT" NLM_WAIT="true" NLM_DOWNLOAD="${DOWNLOAD_DIR:-}" python3 - "$RESULTS_TMP" <<'PY'
import json
import os
import sys

results_file = sys.argv[1]
artifacts = []
with open(results_file, "r", encoding="utf-8") as f:
  for line in f:
    line = line.strip()
    if not line:
      continue
    atype, aid = line.split("|", 1)
    artifacts.append({"type": atype, "artifact_id": aid})

print(json.dumps({
  "notebook_id": os.environ["NLM_NB_ID"],
  "wait": True,
  "successful": int(os.environ["NLM_OK"]),
  "failed": int(os.environ["NLM_FAIL"]),
  "download_dir": os.environ.get("NLM_DOWNLOAD") or None,
  "artifacts": artifacts,
}))
PY
  fi

  exit $FAILED_COUNT
else
  log_info "Background jobs launched (not waiting)"
  log_info "Job PIDs: ${PIDS[*]}"
  log_info ""
  log_info "Monitor with: jobs -l"
  log_info "Wait for all: wait ${PIDS[*]}"

  if [[ "$JSON_OUTPUT" == true ]]; then
    PIDS_JOINED="${PIDS[*]}"
    TYPES_JOINED="${ARTIFACT_TYPES[*]}"
    NLM_NB_ID="$NOTEBOOK_ID" NLM_PIDS="$PIDS_JOINED" NLM_TYPES="$TYPES_JOINED" python3 -c '
import json, os
pids = [p for p in os.environ.get("NLM_PIDS","").split() if p]
types = [t for t in os.environ.get("NLM_TYPES","").split() if t]
print(json.dumps({"notebook_id": os.environ["NLM_NB_ID"], "wait": False, "pids": pids, "artifact_types": types}))'
  fi
fi
