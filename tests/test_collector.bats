#!/usr/bin/env bats

setup() {
  # shellcheck disable=SC1091
  source "$(dirname "$BATS_TEST_FILENAME")/../lib/collector.sh"
}

@test "json_escape handles quotes and backslashes" {
  result="$(json_escape 'say "hello" \ path')"
  [[ "$result" == 'say \"hello\" \\ path' ]]
}

@test "json_escape handles tab and newlines" {
  result="$(json_escape $'line1\nline2\twith tab')"
  [[ "$result" == 'line1\nline2\twith tab' ]]
}

@test "flush_snapshot produces jq-valid JSON with multiline artifacts" {
  # shellcheck disable=SC1091
  source "$(dirname "$BATS_TEST_FILENAME")/../lib/common.sh"
  init_collector
  set_artifact "dmesg_errors" $'[    1.234] driver: probe failed\tcode=-19\n[    2.345] second line'
  export REPORT_FORMAT="json"
  export REPORT_TEMPLATE="community"
  export PROFILE_NAME="generic"
  PASS_COUNT=1; WARN_COUNT=0; FAIL_COUNT=0
  local outfile
  outfile="$(mktemp)"
  flush_snapshot "$outfile"
  if command -v jq &>/dev/null; then
    jq empty "$outfile"
  else
    grep -q '\\t' "$outfile"
    grep -q '\\n' "$outfile"
  fi
  rm -f "$outfile"
}

@test "init_collector resets state" {
  init_collector
  record_check "kernel" "pass" "test message"
  init_collector
  result="$(build_checks_json)"
  [[ "$result" == "{}" ]]
}

@test "flush_snapshot writes valid JSON file" {
  # shellcheck disable=SC1091
  source "$(dirname "$BATS_TEST_FILENAME")/../lib/common.sh"
  init_collector
  record_check "kernel" "pass" "Running kernel: 6.12.5"
  record_check "kernel" "warn" "Kernel tainted"
  export REPORT_FORMAT="json"
  export REPORT_TEMPLATE="community"
  export PROFILE_NAME="generic"
  PASS_COUNT=1; WARN_COUNT=1; FAIL_COUNT=0
  local outfile
  outfile="$(mktemp)"
  flush_snapshot "$outfile"
  [[ -f "$outfile" ]]
  grep -q '"version": "2.0"' "$outfile"
  grep -q '"kernel"' "$outfile"
  grep -q '"status": "warn"' "$outfile"
  rm -f "$outfile"
}
