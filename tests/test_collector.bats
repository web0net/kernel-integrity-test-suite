#!/usr/bin/env bats

setup() {
  # shellcheck disable=SC1091
  source "$(dirname "$BATS_TEST_FILENAME")/../lib/collector.sh"
}

@test "json_escape handles quotes and backslashes" {
  result="$(json_escape 'say "hello" \ path')"
  [[ "$result" == 'say \"hello\" \\ path' ]]
}

@test "init_collector resets state" {
  init_collector
  record_check "kernel" "pass" "test message"
  init_collector
  result="$(build_checks_json)"
  [[ "$result" == "{}" ]]
}
