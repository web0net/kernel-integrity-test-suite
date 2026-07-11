#!/usr/bin/env bash

SND_MODULE_PATTERN='^snd_'

count_alsa_cards() {
  local cards_file="${1:-/proc/asound/cards}"
  [[ -r "$cards_file" ]] || { echo "0"; return; }
  grep -cE '^ [0-9]+\s+\[' "$cards_file" 2>/dev/null || echo "0"
}

parse_alsa_card_names() {
  local cards_file="${1:-/proc/asound/cards}"
  [[ -r "$cards_file" ]] || { echo ""; return; }
  sed -E -n 's/^ [0-9]+ +\[([^]]*)\].*/\1/p' "$cards_file" | tr '\n' ',' | sed 's/,$//'
}

parse_alsa_card_drivers() {
  local cards_file="${1:-/proc/asound/cards}"
  [[ -r "$cards_file" ]] || { echo ""; return; }
  awk '/^ [0-9]+ \[/ {card=$0} /^[[:space:]]{6,}/ && card != "" {print card " -> " $0}' "$cards_file" | head -20
}

snd_module_grep() {
  local text="$1"
  echo "$text" | awk '{print $1}' | grep -E "$SND_MODULE_PATTERN" || true
}

count_snd_devices() {
  find /dev/snd -maxdepth 1 -name 'controlC*' 2>/dev/null | wc -l | tr -d ' '
}
