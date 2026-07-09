#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# shellcheck source=lib/collector.sh
source "${SCRIPT_DIR}/lib/collector.sh"

load_profile() {
  local name="${1:-auto}"
  local model
  model="$(read_file /sys/firmware/devicetree/base/model)"

  if [[ "$name" == "auto" ]]; then
    if [[ "$model" == *"Orange Pi 6"* ]] || [[ "$model" == *"Sky1"* ]]; then
      name="sky1"
    else
      name="generic"
    fi
  fi

  local profile="${SCRIPT_DIR}/profiles/${name}.conf"
  [[ -f "$profile" ]] || { echo "Unknown profile: $name" >&2; exit 2; }
  # shellcheck source=/dev/null
  source "$profile"
  PROFILE_NAME="$name"
}

run_check() {
  local check="$1"
  local file="${SCRIPT_DIR}/checks/${check}.sh"
  [[ -f "$file" ]] || { fail "Missing check module: $check"; return; }
  # shellcheck source=/dev/null
  source "$file"
  "check_${check}"
}

print_summary() {
  section "Summary"
  info "Passed: ${PASS_COUNT}  Warnings: ${WARN_COUNT}  Failed: ${FAIL_COUNT}"
  if [[ "${JSON_OUTPUT:-}" == "1" ]]; then
    printf '{"profile":"%s","pass":%d,"warn":%d,"fail":%d}\n' \
      "${PROFILE_NAME:-unknown}" "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
  fi
  [[ $FAIL_COUNT -eq 0 ]]
}
