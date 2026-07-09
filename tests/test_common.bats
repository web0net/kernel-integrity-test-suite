#!/usr/bin/env bats

setup() {
  # shellcheck disable=SC1091
  source "$(dirname "$BATS_TEST_FILENAME")/../lib/common.sh"
  reset_counters
}

@test "ok increments pass counter" {
  NO_COLOR=1 ok "hello"
  [[ $PASS_COUNT -eq 1 ]]
  [[ $FAIL_COUNT -eq 0 ]]
}

@test "fail increments fail counter" {
  NO_COLOR=1 fail "broken"
  [[ $FAIL_COUNT -eq 1 ]]
}
