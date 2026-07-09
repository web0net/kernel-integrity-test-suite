#!/usr/bin/env bash
set -euo pipefail

COLLECTOR_VERSION="2.0"
declare -gA CHECK_STATUS=()
declare -gA CHECK_ITEMS=()
declare -gA ARTIFACTS=()

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/}"
  printf '%s' "$s"
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
      [[ "${CHECK_STATUS[$category]:-}" != "fail" ]] && CHECK_STATUS["$category"]="warn"
      ;;
    pass)
      [[ -z "${CHECK_STATUS[$category]:-}" ]] && CHECK_STATUS["$category"]="pass"
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
