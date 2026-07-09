#!/usr/bin/env bash
# Copyright (C) 2026 webnetbt@gmail.com
# SPDX-License-Identifier: GPL-2.0-or-later
# shellcheck disable=SC2015,SC2012
# checks/gpu.sh
check_gpu() {
  section "GPU / DRM"

  SCRIPT_DIR_GPU="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  # shellcheck source=lib/gpu_info.sh
  source "${SCRIPT_DIR_GPU}/lib/gpu_info.sh"

  local cards render_count drivers mods driver_summary
  cards="$(ls /dev/dri/card* 2>/dev/null | wc -l | tr -d ' ')"
  render_count="$(ls /dev/dri/renderD* 2>/dev/null | wc -l | tr -d ' ')"

  if [[ "$cards" -gt 0 ]]; then
    ok "DRM cards: ${cards} ($(ls /dev/dri/card* 2>/dev/null | tr '\n' ' '))"
  else
    warn "No DRM card devices under /dev/dri/"
  fi

  if [[ "$render_count" -gt 0 ]]; then
    ok "Render nodes: ${render_count} ($(ls /dev/dri/renderD* 2>/dev/null | tr '\n' ' '))"
  else
    warn "No DRM render nodes"
  fi

  drivers="$(collect_drm_drivers)"
  if [[ -n "$drivers" ]]; then
    ok "DRM kernel driver(s): ${drivers}"
    set_artifact "gpu_drivers" "$drivers"
  else
    warn "No DRM driver bound in sysfs (card*/device/driver)"
  fi

  mods="$(gpu_module_grep "$(lsmod 2>/dev/null)")"
  if [[ -n "$mods" ]]; then
    ok "GPU modules loaded: $(echo "$mods" | tr '\n' ' ')"
    set_artifact "gpu_modules" "$(echo "$mods" | tr '\n' ',')"
  else
    warn "No GPU DRM modules in lsmod"
  fi

  driver_summary=""
  for mod in $mods; do
    if modinfo "$mod" &>/dev/null; then
      local ver desc
      ver="$(modinfo "$mod" 2>/dev/null | sed -n 's/^version:[[:space:]]*//p' | head -1)"
      desc="$(modinfo "$mod" 2>/dev/null | sed -n 's/^description:[[:space:]]*//p' | head -1)"
      if [[ -n "$ver" ]]; then
        ok "Module ${mod}: version ${ver}"
        driver_summary+="${mod}=${ver}; "
      elif [[ -n "$desc" ]]; then
        info "Module ${mod}: ${desc}"
        driver_summary+="${mod}=${desc}; "
      else
        info "Module ${mod}: (no version field in modinfo)"
      fi
    fi
  done
  [[ -n "$driver_summary" ]] && set_artifact "gpu_driver_versions" "${driver_summary%; }"

  if [[ -n "${GPU_EXPECTED_DRIVER:-}" ]]; then
    if [[ "$drivers" == *"${GPU_EXPECTED_DRIVER}"* ]]; then
      ok "Expected GPU driver present: ${GPU_EXPECTED_DRIVER}"
    else
      fail "Expected GPU driver '${GPU_EXPECTED_DRIVER}' not bound (got: ${drivers:-none})"
    fi
  fi

  if [[ -n "${GPU_EXPECTED_MODULES:-}" ]]; then
    for mod in ${GPU_EXPECTED_MODULES}; do
      if lsmod 2>/dev/null | awk '{print $1}' | grep -qx "$mod"; then
        ok "Expected GPU module loaded: ${mod}"
      elif modprobe -n "$mod" &>/dev/null; then
        warn "GPU module ${mod} available but not loaded"
      else
        fail "GPU module ${mod} not available (modprobe -n failed)"
      fi
    done
  fi

  if [[ -n "${GPU_DMESG_PATTERN:-}" ]]; then
    if dmesg 2>/dev/null | grep -q "${GPU_DMESG_PATTERN}"; then
      ok "GPU dmesg match: ${GPU_DMESG_PATTERN}"
    else
      fail "GPU pattern not found in dmesg: ${GPU_DMESG_PATTERN}"
    fi
  fi

  if [[ "${PROFILE_NAME:-}" == "sky1" ]]; then
    dmesg 2>/dev/null | grep -q "ACE-Lite bus coherency" && ok "ACE-Lite bus coherency" || warn "ACE-Lite coherency not confirmed"
    dmesg 2>/dev/null | grep -q "CSF FW" && \
      ok "CSF firmware: $(dmesg 2>/dev/null | grep 'CSF FW' | grep -o 'v[0-9.]*' | head -1)" || \
      fail "CSF firmware missing — check /lib/firmware/arm/mali/"
    dmesg 2>/dev/null | grep -q "Initialized panthor" && \
      ok "$(dmesg 2>/dev/null | grep 'Initialized panthor' | grep -o 'panthor [0-9.]*' | head -1) initialized" || \
      fail "panthor driver not initialized in dmesg"
  fi

  local gpu_errors
  gpu_errors="$(dmesg 2>/dev/null | grep -iE 'gpu|drm|panthor|mali|amdgpu|i915' | grep -iE 'fail|error|unable' | tail -10 || true)"
  if [[ -z "$gpu_errors" ]]; then
    ok "No GPU/DRM errors in dmesg"
  else
    warn "GPU/DRM errors in dmesg (see report artifacts)"
    set_artifact "gpu_dmesg_errors" "$gpu_errors"
  fi

  if command -v vulkaninfo &>/dev/null; then
    ok "Vulkan device: $(vulkaninfo --summary 2>/dev/null | grep deviceName | head -1 | sed 's/.*deviceName = //')"
  else
    info "vulkaninfo not installed (optional)"
  fi
}
