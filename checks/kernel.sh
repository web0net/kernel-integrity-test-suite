check_kernel() {
  section "Kernel"

  local running ver
  running="$(uname -r)"
  ok "Running kernel: ${running}"

  if [[ -f "/boot/vmlinuz-${running}" ]] || [[ -f "/boot/Image-${running}" ]]; then
    ok "Boot image present for ${running}"
  else
    fail "No /boot/vmlinuz-${running} or /boot/Image-${running} — kernel may not be installed"
  fi

  if [[ -d "/lib/modules/${running}" ]]; then
    ok "Module tree: /lib/modules/${running}"
  else
    fail "Missing /lib/modules/${running} — run make modules_install && depmod"
  fi

  if [[ -f "/lib/modules/${running}/modules.dep" ]]; then
    ok "modules.dep exists"
  else
    fail "modules.dep missing — run depmod -a ${running}"
  fi

  if [[ -r /proc/config.gz ]]; then
    ok "Kernel config available via /proc/config.gz"
  else
    warn "CONFIG_IKCONFIG not enabled — cannot read /proc/config.gz"
  fi

  local taint
  taint="$(cat /proc/sys/kernel/tainted 2>/dev/null || echo 0)"
  if [[ "$taint" == "0" ]]; then
    ok "Kernel not tainted"
  else
    warn "Kernel tainted (flags=${taint}) — see Documentation/admin-guide/tainted-kernels.rst"
  fi

  local cmdline
  cmdline="$(read_file /proc/cmdline)"
  [[ -n "$cmdline" ]] && ok "Cmdline: ${cmdline}" || warn "Empty /proc/cmdline"
  set_artifact "cmdline" "$cmdline"
  set_artifact "taint_raw" "$taint"

  local machine
  machine="$(read_file /sys/firmware/devicetree/base/model)"
  [[ -n "$machine" ]] && ok "Board: ${machine}" || info "No devicetree model (likely x86/UEFI)"
}
