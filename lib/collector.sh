#!/usr/bin/env bash
set -euo pipefail

COLLECTOR_VERSION="2.0"
declare -gA CHECK_STATUS=()
declare -gA CHECK_ITEMS=()
declare -gA ARTIFACTS=()

json_escape() {
  local s="$1" out="" i c ord hex
  for ((i = 0; i < ${#s}; i++)); do
    c="${s:i:1}"
    case "$c" in
      "\\") out+='\\' ;;
      '"') out+='\"' ;;
      $'\n') out+='\n' ;;
      $'\r') out+='\r' ;;
      $'\t') out+='\t' ;;
      $'\b') out+='\b' ;;
      $'\f') out+='\f' ;;
      *)
        ord=$(LC_ALL=C printf '%d' "'$c" 2>/dev/null || echo -1)
        if [[ "$ord" -ge 0 && "$ord" -lt 32 ]]; then
          hex=$(printf '%04x' "$ord")
          out+='\\u'"${hex}"
        else
          out+="$c"
        fi
        ;;
    esac
  done
  printf '%s' "$out"
}

init_collector() {
  declare -gA CHECK_STATUS=()
  declare -gA CHECK_ITEMS=()
  declare -gA ARTIFACTS=()
}

record_check() {
  local category="$1" level="$2" message="$3"
  local escaped
  escaped="$(json_escape "$message")"
  CHECK_ITEMS["$category"]+="{ \"level\": \"${level}\", \"message\": \"${escaped}\" },"
  case "$level" in
    fail) CHECK_STATUS["$category"]="fail" ;;
    warn)
      if [[ "${CHECK_STATUS[$category]:-}" != "fail" ]]; then
        CHECK_STATUS["$category"]="warn"
      fi
      ;;
    pass)
      if [[ -z "${CHECK_STATUS[$category]:-}" ]]; then
        CHECK_STATUS["$category"]="pass"
      fi
      ;;
  esac
}

set_artifact() {
  local key="$1" value="$2"
  ARTIFACTS["$key"]="$value"
}

build_checks_json() {
  local cat result="{"
  local first=1
  for cat in "${!CHECK_ITEMS[@]}"; do
    local items="${CHECK_ITEMS[$cat]%,}"
    local status="${CHECK_STATUS[$cat]:-pass}"
    [[ $first -eq 0 ]] && result+=","
    first=0
    result+="\"${cat}\":{\"status\":\"${status}\",\"items\":[${items}]}"
  done
  result+="}"
  printf '%s' "$result"
}


_summary_status() {
  [[ "${FAIL_COUNT:-0}" -gt 0 ]] && { echo "fail"; return; }
  [[ "${WARN_COUNT:-0}" -gt 0 ]] && { echo "warn"; return; }
  echo "pass"
}

_iso_timestamp() {
  date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z'
}

flush_snapshot() {
  local outfile="$1"
  local ts kernel hostname board
  ts="$(_iso_timestamp)"
  kernel="$(uname -r)"
  hostname="$(hostname 2>/dev/null || echo unknown)"
  board="$(read_file /sys/firmware/devicetree/base/model 2>/dev/null || echo "")"
  [[ -z "$board" ]] && board="unknown"

  local artifacts_json="{"
  local af=1
  for key in "${!ARTIFACTS[@]}"; do
    [[ $af -eq 0 ]] && artifacts_json+=","
    af=0
    artifacts_json+="\"${key}\":\"$(json_escape "${ARTIFACTS[$key]}")\""
  done
  artifacts_json+="}"

  local diff_json="${DIFF_JSON:-"{}"}"

  cat >"$outfile" <<EOF
{
  "meta": {
    "version": "${COLLECTOR_VERSION}",
    "timestamp": "${ts}",
    "hostname": "$(json_escape "$hostname")",
    "profile": "${PROFILE_NAME:-unknown}",
    "board": "$(json_escape "$board")",
    "kernel": "$(json_escape "$kernel")",
    "template": "${REPORT_TEMPLATE:-community}",
    "format": "${REPORT_FORMAT:-json}",
    "limited_access": ${LIMITED_ACCESS:-false}
  },
  "summary": {
    "pass": ${PASS_COUNT:-0},
    "warn": ${WARN_COUNT:-0},
    "fail": ${FAIL_COUNT:-0},
    "status": "$(_summary_status)"
  },
  "checks": $(build_checks_json),
  "artifacts": ${artifacts_json},
  "diff": ${diff_json}
}
EOF
}
