#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FROM=""
REPORT=""
TEMPLATE=""
OUTPUT=""

usage() {
  echo "Usage: render.sh --from <snapshot.json> --report <fmt> --template <name> --output <file>" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      FROM="$2"
      shift 2
      ;;
    --report)
      REPORT="$2"
      shift 2
      ;;
    --template)
      TEMPLATE="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

[[ -n "$FROM" && -n "$REPORT" && -n "$TEMPLATE" && -n "$OUTPUT" ]] || usage

if [[ ! -f "$FROM" ]]; then
  echo "Snapshot not found: $FROM" >&2
  exit 1
fi

TEMPLATE_FILE="${SCRIPT_DIR}/templates/${TEMPLATE}.${REPORT}.tpl"
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Template not found: $TEMPLATE_FILE" >&2
  exit 1
fi

_has_jq() {
  command -v jq &>/dev/null
}

# shellcheck disable=SC2034
_json_get() {
  local filter="$1"
  if _has_jq; then
    jq -r "$filter" "$FROM"
    return
  fi

  case "$filter" in
    .meta.kernel)
      _fallback_meta_string kernel
      ;;
    .meta.board)
      _fallback_meta_string board
      ;;
    .meta.hostname)
      _fallback_meta_string hostname
      ;;
    .meta.timestamp)
      _fallback_meta_string timestamp
      ;;
    .meta.profile)
      _fallback_meta_string profile
      ;;
    .summary.status)
      _fallback_summary_string status
      ;;
    .summary.pass)
      _fallback_summary_number pass
      ;;
    .summary.warn)
      _fallback_summary_number warn
      ;;
    .summary.fail)
      _fallback_summary_number fail
      ;;
    .diff.note)
      _fallback_diff_note
      ;;
    *)
      echo ""
      ;;
  esac
}

_fallback_meta_string() {
  local field="$1"
  sed -n 's/.*"meta"[[:space:]]*:[[:space:]]*{[^}]*"'"${field}"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FROM" | head -1
}

_fallback_summary_string() {
  local field="$1"
  sed -n 's/.*"summary"[[:space:]]*:[[:space:]]*{[^}]*"'"${field}"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FROM" | head -1
}

_fallback_summary_number() {
  local field="$1"
  sed -n 's/.*"summary"[[:space:]]*:[[:space:]]*{[^}]*"'"${field}"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$FROM" | head -1
}

_fallback_diff_note() {
  sed -n 's/.*"diff"[[:space:]]*:[[:space:]]*{[^}]*"note"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FROM" | head -1
}

_build_checks_block() {
  if _has_jq; then
    jq -r '
      .checks
      | to_entries[]
      | "### \(.key) (\(.value.status))\n"
        + (.value.items[]? | "- [\(.level)] \(.message)\n")
    ' "$FROM" 2>/dev/null || echo ""
    return
  fi
  echo ""
}

_build_problems_block() {
  if _has_jq; then
    jq -r '
      .checks
      | to_entries[]
      | .value.items[]?
      | select(.level == "warn" or .level == "fail")
      | "- [\(.level)] \(.message)"
    ' "$FROM" 2>/dev/null || echo ""
    return
  fi
  echo ""
}

KERNEL="$(_json_get .meta.kernel)"
BOARD="$(_json_get .meta.board)"
HOSTNAME="$(_json_get .meta.hostname)"
TIMESTAMP="$(_json_get .meta.timestamp)"
PROFILE="$(_json_get .meta.profile)"
SUMMARY_STATUS="$(_json_get .summary.status)"
SUMMARY_PASS="$(_json_get .summary.pass)"
SUMMARY_WARN="$(_json_get .summary.warn)"
SUMMARY_FAIL="$(_json_get .summary.fail)"
DIFF_SUMMARY="$(_json_get .diff.note)"
CHECKS_BLOCK="$(_build_checks_block)"
PROBLEMS_BLOCK="$(_build_problems_block)"

export KERNEL BOARD HOSTNAME TIMESTAMP PROFILE
export SUMMARY_STATUS SUMMARY_PASS SUMMARY_WARN SUMMARY_FAIL
export CHECKS_BLOCK PROBLEMS_BLOCK DIFF_SUMMARY

_sed_oneline() {
  local v="$1"
  v="${v//$'\n'/ }"
  printf '%s' "$v" | sed -e 's/[&|\\]/\\&/g'
}

CHECKS_BLOCK="$(_sed_oneline "$CHECKS_BLOCK")"
PROBLEMS_BLOCK="$(_sed_oneline "$PROBLEMS_BLOCK")"
DIFF_SUMMARY="$(_sed_oneline "$DIFF_SUMMARY")"

sed \
  -e "s|{{kernel}}|${KERNEL}|g" \
  -e "s|{{board}}|${BOARD}|g" \
  -e "s|{{hostname}}|${HOSTNAME}|g" \
  -e "s|{{timestamp}}|${TIMESTAMP}|g" \
  -e "s|{{profile}}|${PROFILE}|g" \
  -e "s|{{summary_status}}|${SUMMARY_STATUS}|g" \
  -e "s|{{summary_pass}}|${SUMMARY_PASS}|g" \
  -e "s|{{summary_warn}}|${SUMMARY_WARN}|g" \
  -e "s|{{summary_fail}}|${SUMMARY_FAIL}|g" \
  -e "s|{{checks_block}}|${CHECKS_BLOCK}|g" \
  -e "s|{{problems_block}}|${PROBLEMS_BLOCK}|g" \
  -e "s|{{diff_summary}}|${DIFF_SUMMARY}|g" \
  "$TEMPLATE_FILE" >"$OUTPUT"
