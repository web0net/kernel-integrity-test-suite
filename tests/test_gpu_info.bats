#!/usr/bin/env bats

setup() {
  FIXTURES="$(dirname "$BATS_TEST_FILENAME")/fixtures/gpu"
  # shellcheck disable=SC1091
  source "$(dirname "$BATS_TEST_FILENAME")/../lib/gpu_info.sh"
}

@test "parse_modinfo_version extracts version field" {
  result="$(parse_modinfo_version "${FIXTURES}/modinfo_panthor.txt")"
  [[ "$result" == "1.3.0" ]]
}

@test "normalize_drm_driver reads driver name from path file" {
  result="$(normalize_drm_driver "${FIXTURES}/drm_driver_name.txt")"
  [[ "$result" == "panthor" ]]
}

@test "gpu_module_grep filters lsmod lines" {
  local lsmod="panthor 123 0\nsnd_soc_hdmi 0 0"
  result="$(gpu_module_grep "$lsmod")"
  [[ "$result" == *"panthor"* ]]
  [[ "$result" != *"snd_soc"* ]]
}
