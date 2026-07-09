# checks/storage.sh
check_storage() {
  section "Storage"

  local root_src root_opts
  root_src="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
  root_opts="$(findmnt -n -o OPTIONS / 2>/dev/null || true)"
  if [[ -n "$root_src" ]]; then
    ok "Root filesystem: ${root_src}"
    if [[ "$root_opts" == *rw* ]]; then
      ok "Root mounted read-write"
    else
      fail "Root not mounted rw (options: ${root_opts})"
    fi
  else
    fail "Cannot determine root mount"
  fi

  local block_count
  block_count="$(lsblk -d -n -o NAME 2>/dev/null | wc -l | tr -d ' ')"
  ok "Block devices: ${block_count}"

  if ls /dev/nvme*n* &>/dev/null; then
    local dev size
    dev="$(ls /dev/nvme*n* | head -1)"
    size="$(lsblk -d -n -o SIZE "$dev" 2>/dev/null | tr -d ' ')"
    ok "NVMe: ${dev} (${size})"
  else
    info "No NVMe namespace detected"
  fi

  if dmesg 2>/dev/null | grep -qiE 'I/O error|Buffer I/O error|EXT4-fs error'; then
    fail "Storage I/O errors in dmesg"
  else
    ok "No storage I/O errors in dmesg"
  fi
}
