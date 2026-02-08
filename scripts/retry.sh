#!/usr/bin/env bash
set -euo pipefail

# Shared retry/backoff helper for transient failures.
#
# Configuration (env vars):
#   NLM_RETRY_ATTEMPTS   (default: 3)
#   NLM_RETRY_BASE_SLEEP (default: 1)
#   NLM_RETRY_MAX_SLEEP  (default: 8)
#   NLM_RETRY_EXIT_CODES (optional, space-separated; if set, only retry these codes)
#   NLM_NO_RETRY         ("true" disables retries; scripts wire this from --no-retry)

_nlm__is_int() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

_nlm__exit_code_retryable() {
  local rc="$1"

  if [[ -z "${NLM_RETRY_EXIT_CODES:-}" ]]; then
    return 0
  fi

  local c
  for c in $NLM_RETRY_EXIT_CODES; do
    if [[ "$c" == "$rc" ]]; then
      return 0
    fi
  done

  return 1
}

retry_cmd() {
  local desc="$1"
  shift

  local max_attempts="${NLM_RETRY_ATTEMPTS:-3}"
  local base_sleep="${NLM_RETRY_BASE_SLEEP:-1}"
  local max_sleep="${NLM_RETRY_MAX_SLEEP:-8}"

  if ! _nlm__is_int "$max_attempts" || [[ "$max_attempts" -lt 1 ]]; then
    echo "[retry] invalid NLM_RETRY_ATTEMPTS=$max_attempts (expected int >= 1)" >&2
    max_attempts=3
  fi
  if ! _nlm__is_int "$base_sleep"; then
    echo "[retry] invalid NLM_RETRY_BASE_SLEEP=$base_sleep (expected int)" >&2
    base_sleep=1
  fi
  if ! _nlm__is_int "$max_sleep"; then
    echo "[retry] invalid NLM_RETRY_MAX_SLEEP=$max_sleep (expected int)" >&2
    max_sleep=8
  fi

  local attempt=1
  local rc=0

  while true; do
    # Preserve caller's errexit behavior while allowing the command to fail
    # without aborting the entire script (required for retry loops).
    local errexit_was_set=0
    case $- in
      *e*) errexit_was_set=1 ;;
    esac
    set +e
    "$@"
    rc=$?
    if [[ $errexit_was_set -eq 1 ]]; then
      set -e
    fi

    if [[ $rc -eq 0 ]]; then
      return 0
    fi

    if [[ "${NLM_NO_RETRY:-false}" == "true" ]]; then
      return "$rc"
    fi

    if [[ $attempt -ge $max_attempts ]]; then
      return "$rc"
    fi

    if ! _nlm__exit_code_retryable "$rc"; then
      return "$rc"
    fi

    # Exponential backoff (base * 2^(attempt-1)), clamped.
    local sleep_s=$(( base_sleep * (1 << (attempt - 1)) ))
    if [[ $sleep_s -gt $max_sleep ]]; then
      sleep_s=$max_sleep
    fi

    echo "[retry] $desc: attempt $attempt/$max_attempts failed (exit $rc); retrying in ${sleep_s}s" >&2
    sleep "$sleep_s"
    attempt=$(( attempt + 1 ))
  done
}
