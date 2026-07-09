# checks/cgroups.sh
check_cgroups() {
  section "Cgroups"

  if mountpoint -q /sys/fs/cgroup 2>/dev/null; then
    ok "cgroup filesystem mounted at /sys/fs/cgroup"
  else
    fail "cgroup not mounted at /sys/fs/cgroup"
    return
  fi

  if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
    local controllers
    controllers="$(read_file /sys/fs/cgroup/cgroup.controllers)"
    if [[ -n "$controllers" ]]; then
      ok "cgroup v2 controllers: ${controllers}"
    else
      warn "cgroup.controllers empty"
    fi
  else
    warn "cgroup.controllers missing — likely cgroup v1 hybrid or misconfigured mount"
  fi

  if command -v systemctl &>/dev/null; then
    if systemctl is-system-running &>/dev/null || systemctl --version &>/dev/null; then
      info "systemd manages cgroup delegation (Delegate= in unit files affects user slices)"
    fi
  else
    info "systemd not detected — verify cgroup delegation for your init"
  fi
}
