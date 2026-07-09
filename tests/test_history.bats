#!/usr/bin/env bats

setup() {
  KERNEL_CHECK_HOME="$(mktemp -d)"
  export KERNEL_CHECK_HOME
  # shellcheck disable=SC1091
  source "$(dirname "$BATS_TEST_FILENAME")/../lib/history.sh"
}

teardown() {
  rm -rf "$KERNEL_CHECK_HOME"
}

@test "save_snapshot creates timestamped file" {
  local src
  src="$(mktemp)"
  echo '{"meta":{"kernel":"1.0"}}' >"$src"
  local dest
  dest="$(save_snapshot "$src")"
  [[ -f "$dest" ]]
  [[ "$dest" == *".json" ]]
}

@test "list_snapshots returns newest first" {
  mkdir -p "$KERNEL_CHECK_HOME/history"
  echo '{}' >"$KERNEL_CHECK_HOME/history/2026-07-08T10-00-00.json"
  echo '{}' >"$KERNEL_CHECK_HOME/history/2026-07-09T10-00-00.json"
  result="$(list_snapshots)"
  [[ "$result" == *"2026-07-09"* ]]
}

@test "retention keeps only 20 snapshots" {
  mkdir -p "$KERNEL_CHECK_HOME/history"
  local i
  for i in $(seq 1 25); do
    printf '{"i":%d}\n' "$i" >"$KERNEL_CHECK_HOME/history/2026-07-$(printf '%02d' "$i")T00-00-00.json"
  done
  prune_history 20
  count="$(find "$KERNEL_CHECK_HOME/history" -name '*.json' | wc -l | tr -d ' ')"
  [[ "$count" -eq 20 ]]
}

@test "compute_diff detects new failures and kernel change" {
  local prev cur
  prev="$(mktemp)"
  cur="$(mktemp)"
  cat >"$prev" <<'INNER'
{"meta":{"kernel":"6.12.4"},"checks":{"gpu":{"status":"pass","items":[]}},"artifacts":{"dmesg_errors":["old error"],"loaded_modules":["kvm"]}}
INNER
  cat >"$cur" <<'INNER'
{"meta":{"kernel":"6.12.5"},"checks":{"gpu":{"status":"fail","items":[{"level":"fail","message":"DRM missing"}]}},"artifacts":{"dmesg_errors":["old error","new error"],"loaded_modules":["kvm","ext4"]}}
INNER
  result="$(compute_diff "$prev" "$cur")"
  [[ "$result" == *"kernel_changed"*true* ]]
  [[ "$result" == *"DRM missing"* ]]
  [[ "$result" == *"new error"* ]]
  rm -f "$prev" "$cur"
}
