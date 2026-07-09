# checks/gpu.sh
check_gpu() {
  section "GPU / DRM"

  local cards render_count
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

  if [[ -n "${GPU_DMESG_PATTERN:-}" ]]; then
    if dmesg 2>/dev/null | grep -q "${GPU_DMESG_PATTERN}"; then
      ok "GPU dmesg match: ${GPU_DMESG_PATTERN}"
    else
      fail "GPU pattern not found in dmesg: ${GPU_DMESG_PATTERN}"
    fi
  fi

  # Sky1 / Panthor-specific (only when profile is sky1)
  if [[ "${PROFILE_NAME:-}" == "sky1" ]]; then
    dmesg 2>/dev/null | grep -q "ACE-Lite bus coherency" && ok "ACE-Lite bus coherency" || warn "ACE-Lite coherency not confirmed"
    dmesg 2>/dev/null | grep -q "CSF FW" && \
      ok "CSF firmware: $(dmesg | grep 'CSF FW' | grep -o 'v[0-9.]*' | head -1)" || \
      fail "CSF firmware missing — check /lib/firmware/arm/mali/"
    dmesg 2>/dev/null | grep -q "Initialized panthor" && \
      ok "$(dmesg | grep 'Initialized panthor' | grep -o 'panthor [0-9.]*' | head -1) initialized"
  fi

  if command -v vulkaninfo &>/dev/null; then
    ok "Vulkan: $(vulkaninfo --summary 2>/dev/null | grep deviceName | head -1 | awk '{print $3}')"
  else
    info "vulkaninfo not installed (optional)"
  fi
}
