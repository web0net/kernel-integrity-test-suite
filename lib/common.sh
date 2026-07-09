#!/usr/bin/env bash
set -euo pipefail

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

if [[ "${NO_COLOR:-}" == "1" ]]; then
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
else
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
fi

reset_counters() { PASS_COUNT=0; WARN_COUNT=0; FAIL_COUNT=0; }

ok() {
  echo -e "  ${GREEN}✓${NC}  $1"
  PASS_COUNT=$((PASS_COUNT + 1))
  if [[ -n "${CHECK_CATEGORY:-}" ]]; then record_check "$CHECK_CATEGORY" "pass" "$1"; fi
}
warn() {
  echo -e "  ${YELLOW}⚠${NC}  $1"
  WARN_COUNT=$((WARN_COUNT + 1))
  if [[ -n "${CHECK_CATEGORY:-}" ]]; then record_check "$CHECK_CATEGORY" "warn" "$1"; fi
}
fail() {
  echo -e "  ${RED}✗${NC}  $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  if [[ -n "${CHECK_CATEGORY:-}" ]]; then record_check "$CHECK_CATEGORY" "fail" "$1"; fi
}
info() { echo -e "  ${CYAN}→${NC}  $1"; }

section() { echo -e "${YELLOW}---${NC} ${BLUE}$1${NC} ${YELLOW}---${NC}"; }

read_file() {
  local path="$1"
  [[ -r "$path" ]] && tr -d '\0' < "$path" || echo ""
}
