#!/usr/bin/env bash
# checks/tracing.sh
check_tracing() {
  section "Tracing"

  local taint decoded=() raw
  taint="$(cat /proc/sys/kernel/tainted 2>/dev/null || echo 0)"
  raw="$taint"

  _taint_has() {
    local mask="$1"
    (( (taint & mask) != 0 ))
  }

  if _taint_has 1; then decoded+=("proprietary_module"); fi
  if _taint_has 2; then decoded+=("out_of_tree_module"); fi
  if _taint_has 4096; then decoded+=("kernel_warn"); fi
  if _taint_has 8192; then decoded+=("acpi_overridden"); fi

  local decoded_str
  if ((${#decoded[@]} > 0)); then
    decoded_str="$(IFS=,; echo "${decoded[*]}")"
    warn "Kernel tainted (raw=${raw}): ${decoded_str}"
  else
    decoded_str="none"
    ok "No traced taint bits set (raw=${raw})"
  fi
  set_artifact taint_decoded "{\"raw\":${raw},\"decoded\":\"${decoded_str}\"}"

  if mountpoint -q /sys/kernel/debug 2>/dev/null; then
    ok "debugfs mounted at /sys/kernel/debug"
  else
    warn "debugfs not mounted — mount with: mount -t debugfs none /sys/kernel/debug"
  fi

  if [[ -d /sys/kernel/tracing ]] || [[ -d /sys/kernel/debug/tracing ]]; then
    ok "ftrace interface available"
  else
    warn "ftrace tracing directory not found"
  fi
}
