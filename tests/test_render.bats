#!/usr/bin/env bats

@test "render community markdown replaces placeholders" {
  local out
  out="$(mktemp)"
  run render/render.sh --from tests/fixtures/sample-snapshot.json \
    --report md --template community --output "$out"
  [ "$status" -eq 0 ]
  grep -q "6.12.5" "$out"
  grep -q "test board" "$out"
  ! grep -q '{{kernel}}' "$out"
  rm -f "$out"
}
