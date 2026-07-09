# checks/filesystem.sh
check_filesystem() {
  section "Filesystem"

  local root_src root_opts root_fstype
  root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
  root_opts="$(findmnt -n -o OPTIONS / 2>/dev/null || true)"
  root_fstype="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"

  if [[ -n "$root_src" ]]; then
    ok "Root mount: ${root_src} (${root_fstype:-unknown})"
    if [[ "$root_opts" == *rw* ]]; then
      ok "Root filesystem mounted read-write"
    else
      fail "Root not mounted rw (options: ${root_opts:-none})"
    fi
  else
    fail "findmnt could not resolve root mount"
  fi

  if dmesg &>/dev/null; then
    if dmesg 2>/dev/null | grep -qiE 'EXT4-fs error|XFS.*error|BTRFS.*error|VFS:.*error|filesystem error'; then
      fail "Filesystem errors reported in dmesg"
    else
      ok "No filesystem errors in dmesg"
    fi
  else
    warn "Cannot scan dmesg for filesystem errors (limited access)"
  fi

  if [[ "${root_fstype:-}" == "btrfs" ]]; then
    if command -v btrfs &>/dev/null; then
      if btrfs filesystem show / 2>/dev/null | grep -q .; then
        ok "btrfs filesystem show succeeded for /"
      else
        warn "btrfs tools present but could not query root volume"
      fi
    else
      warn "Root is btrfs but btrfs-progs not installed"
    fi
    if [[ -r /sys/fs/btrfs/features ]]; then
      info "btrfs feature sysfs available"
    fi
  else
    info "Root is not btrfs (${root_fstype:-unknown}) — skipping btrfs checks"
  fi
}
