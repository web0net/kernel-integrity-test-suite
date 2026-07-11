#!/usr/bin/env bash
# Copyright (C) 2026 webnetbt@gmail.com
# SPDX-License-Identifier: GPL-2.0-or-later

check_audio() {
  section "Audio / ALSA"

  if [[ "$(uname -s)" != "Linux" ]]; then
    info "Skipping ALSA checks (host is $(uname -s))"
    return 0
  fi

  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  # shellcheck source=lib/audio_info.sh
  source "${script_dir}/lib/audio_info.sh"

  local card_count card_names snd_devs snd_mods alsa_ver

  card_count="$(count_alsa_cards)"
  card_names="$(parse_alsa_card_names)"

  if [[ "$card_count" -gt 0 ]]; then
    ok "ALSA cards: ${card_count} (${card_names})"
    set_artifact "alsa_cards" "$card_names"
  else
    fail "No ALSA sound cards in /proc/asound/cards"
  fi

  if [[ -r /proc/asound/version ]]; then
    alsa_ver="$(tr -d '\n' </proc/asound/version)"
    ok "ALSA version: ${alsa_ver}"
    set_artifact "alsa_version" "$alsa_ver"
  else
    warn "/proc/asound/version not readable"
  fi

  snd_devs="$(count_snd_devices)"
  if [[ "${snd_devs:-0}" -gt 0 ]]; then
    ok "/dev/snd control devices: ${snd_devs}"
  else
    warn "No /dev/snd/controlC* devices — snd device nodes missing?"
  fi

  snd_mods="$(snd_module_grep "$(lsmod 2>/dev/null)")"
  if [[ -n "$snd_mods" ]]; then
    ok "Audio modules loaded: $(echo "$snd_mods" | tr '\n' ' ')"
    set_artifact "audio_modules" "$(echo "$snd_mods" | tr '\n' ',')"
  else
    warn "No snd_* modules loaded in lsmod"
  fi

  if [[ "${AUDIO_MIN_CARDS:-0}" -gt 0 ]]; then
    if [[ "$card_count" -ge "${AUDIO_MIN_CARDS}" ]]; then
      ok "Card count meets profile minimum (${AUDIO_MIN_CARDS})"
    else
      fail "Expected at least ${AUDIO_MIN_CARDS} ALSA card(s), found ${card_count}"
    fi
  fi

  if [[ -n "${AUDIO_EXPECTED_CARD:-}" ]]; then
    if [[ "$card_names" == *"${AUDIO_EXPECTED_CARD}"* ]]; then
      ok "Expected audio card name match: ${AUDIO_EXPECTED_CARD}"
    else
      warn "Card name '${AUDIO_EXPECTED_CARD}' not found in: ${card_names:-none}"
    fi
  fi

  if [[ -n "${AUDIO_DMESG_PATTERN:-}" ]]; then
    if dmesg 2>/dev/null | grep -q "${AUDIO_DMESG_PATTERN}"; then
      ok "Audio dmesg match: ${AUDIO_DMESG_PATTERN}"
    else
      fail "Audio dmesg pattern not found: ${AUDIO_DMESG_PATTERN}"
    fi
  fi

  local audio_errors
  audio_errors="$(dmesg 2>/dev/null | grep -iE 'snd|sound|audio|hda|hdmi|asoc|alsa' | grep -iE 'fail|error|unable|deferred' | tail -15 || true)"
  if [[ -z "$audio_errors" ]]; then
    ok "No audio init errors in dmesg"
  else
    fail "Audio initialization errors in dmesg (${audio_errors%%$'\n'*}...)"
    set_artifact "audio_dmesg_errors" "$audio_errors"
  fi

  if command -v aplay &>/dev/null; then
    if aplay -l 2>/dev/null | grep -q 'card '; then
      ok "aplay -l reports playback devices"
      set_artifact "aplay_listing" "$(aplay -l 2>/dev/null | head -20)"
    else
      warn "aplay -l found no playback devices"
    fi
  else
    info "aplay not installed (optional: alsa-utils)"
  fi
}
