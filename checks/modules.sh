check_modules() {
  section "Kernel Modules"

  local running vermagic_proc vermagic_mod
  running="$(uname -r)"

  if [[ -f "/lib/modules/${running}/modules.builtin" ]]; then
    local builtin_count
    builtin_count="$(wc -l < "/lib/modules/${running}/modules.builtin")"
    ok "Builtin modules listed: ${builtin_count}"
  fi

  vermagic_proc="$(modprobe -V 2>/dev/null | head -1 || true)"
  if [[ -n "$vermagic_proc" ]]; then
    info "modprobe: ${vermagic_proc}"
  fi

  if [[ -f "/lib/modules/${running}/modules.devname" ]]; then
    ok "modules.devname present (depmod ran)"
  else
    warn "modules.devname missing — run: depmod -a ${running}"
  fi

  if dmesg 2>/dev/null | grep -qiE 'Direct firmware load.*failed|firmware: failed'; then
    fail "Firmware load failures in dmesg — check /lib/firmware"
  else
    ok "No firmware load failures in dmesg"
  fi

  if [[ -n "${MODULE_SMOKE_TEST:-}" ]]; then
    for mod in ${MODULE_SMOKE_TEST}; do
      if modprobe -n "$mod" &>/dev/null; then
        ok "modprobe -n ${mod}: OK"
      else
        fail "modprobe -n ${mod}: FAILED"
      fi
    done
  else
    info "No MODULE_SMOKE_TEST configured for profile"
  fi

  local mods
  mods="$(lsmod 2>/dev/null | awk 'NR>1 {print $1}' | tr '\n' ',' | sed 's/,$//')"
  set_artifact "loaded_modules" "$mods"
}
