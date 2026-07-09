#!/usr/bin/env bats

@test "render community markdown replaces placeholders" {
  local out
  out="$(mktemp)"
  render/render.sh --from tests/fixtures/sample-snapshot.json \
    --report md --template community --output "$out"
  grep -q "6.12.5" "$out"
  grep -q "test board" "$out"
  run grep -q '{{' "$out"
  [ "$status" -eq 1 ]
  rm -f "$out"
}

@test "render community html has no unreplaced placeholders" {
  local out
  out="$(mktemp)"
  render/render.sh --from tests/fixtures/sample-snapshot.json \
    --report html --template community --output "$out"
  grep -q "Kernel Check Report" "$out"
  grep -q 'class="banner warn"' "$out"
  run grep -q '{{' "$out"
  [ "$status" -eq 1 ]
  rm -f "$out"
}

@test "render developer html has no unreplaced placeholders" {
  local out
  out="$(mktemp)"
  render/render.sh --from tests/fixtures/sample-snapshot.json \
    --report html --template developer --output "$out"
  grep -q "Kernel Check Report" "$out"
  grep -q "kernel" "$out"
  run grep -q '{{' "$out"
  [ "$status" -eq 1 ]
  rm -f "$out"
}

@test "render developer markdown includes detail sections" {
  local out
  out="$(mktemp)"
  render/render.sh --from tests/fixtures/sample-snapshot.json \
    --report md --template developer --output "$out"
  grep -q "## Check Details" "$out"
  grep -q "<details>" "$out"
  grep -q "## Diff" "$out"
  grep -q "sample-snapshot.json" "$out"
  run grep -q '{{' "$out"
  [ "$status" -eq 1 ]
  rm -f "$out"
}
