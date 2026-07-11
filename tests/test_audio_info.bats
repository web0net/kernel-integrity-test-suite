#!/usr/bin/env bats

setup() {
  FIXTURES="$(dirname "$BATS_TEST_FILENAME")/fixtures/audio"
  # shellcheck disable=SC1091
  source "$(dirname "$BATS_TEST_FILENAME")/../lib/audio_info.sh"
}

@test "count_alsa_cards returns card count" {
  result="$(count_alsa_cards "${FIXTURES}/cards")"
  [[ "$result" == "2" ]]
}

@test "parse_alsa_card_names extracts names" {
  result="$(parse_alsa_card_names "${FIXTURES}/cards")"
  [[ "$result" == *"HDAudio"* ]]
  [[ "$result" == *"HDMI"* ]]
}

@test "snd_module_grep filters snd modules" {
  result="$(snd_module_grep "$(cat "${FIXTURES}/lsmod_snd.txt")")"
  [[ "$result" == *"snd_soc_hdmi"* ]]
  [[ "$result" != *"panthor"* ]]
}
