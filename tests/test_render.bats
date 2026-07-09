#!/usr/bin/env bats

@test "render community markdown replaces placeholders" {
  local out
  out="$(mktemp)"
  run render/render.sh --from tests/fixtures/sample-snapshot.json \
    --report md --template community --output "$out"
  [ "$status" -eq 0 ]
  grep -q "6.12.5" "$out"
  grep -q "test board" "$out"
  ! grep -q '{{' "$out"
  rm -f "$out"
}

@test "render community html has no unreplaced placeholders" {
  local out
  out="$(mktemp)"
  run render/render.sh --from tests/fixtures/sample-snapshot.json \
    --report html --template community --output "$out"
  [ "$status" -eq 0 ]
  grep -q "Kernel Check Report" "$out"
  grep -q 'class="banner warn"' "$out"
  ! grep -q '{{' "$out"
  rm -f "$out"
}

@test "render developer markdown includes detail sections" {
  local out
  out="$(mktemp)"
  run render/render.sh --from tests/fixtures/sample-snapshot.json \
    --report md --template developer --output "$out"
  [ "$status" -eq 0 ]
  grep -q "## Check Details" "$out"
  grep -q "<details>" "$out"
  grep -q "## Diff" "$out"
  grep -q "sample-snapshot.json" "$out"
  ! grep -q '{{' "$out"
  rm -f "$out"
}
