check_boot() {
  section "Boot"

  local running uptime_secs
  running="$(uname -r)"
  uptime_secs="$(cut -d. -f1 /proc/uptime)"

  if [[ "${uptime_secs:-0}" -lt 60 ]]; then
    warn "System uptime ${uptime_secs}s — some drivers may still be probing"
  else
    ok "Uptime: ${uptime_secs}s"
  fi

  if [[ -f "/boot/initrd.img-${running}" ]] || [[ -f "/boot/initramfs-${running}.img" ]]; then
    ok "Initramfs present for ${running}"
  else
    warn "No initramfs for ${running} — run update-initramfs -u -k ${running} (Debian) or dracut (RHEL)"
  fi

  if command -v systemctl &>/dev/null; then
    local failed
    failed="$(systemctl --failed --no-legend --no-pager 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$failed" == "0" ]]; then
      ok "No failed systemd units"
    else
      fail "systemd reports ${failed} failed unit(s) — run: systemctl --failed"
    fi
  else
    info "systemctl not available (non-systemd init)"
  fi

  if [[ -d /sys/firmware/efi ]]; then
    ok "EFI firmware boot detected"
  else
    info "Non-EFI boot path"
  fi
}
