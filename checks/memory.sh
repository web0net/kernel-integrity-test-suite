# checks/memory.sh
check_memory() {
  section "Memory"

  local mem_total_kb mem_avail_kb mem_total_gb mem_avail_gb
  mem_total_kb="$(grep -E '^MemTotal:' /proc/meminfo | awk '{print $2}')"
  mem_avail_kb="$(grep -E '^MemAvailable:' /proc/meminfo | awk '{print $2}')"
  mem_total_gb=$((mem_total_kb / 1024 / 1024))
  mem_avail_gb=$((mem_avail_kb / 1024 / 1024))

  ok "RAM: ${mem_total_gb} GB total, ${mem_avail_gb} GB available"

  if [[ "${MIN_RAM_GB_FAIL:-0}" -gt 0 && "$mem_total_gb" -lt "$MIN_RAM_GB_FAIL" ]]; then
    fail "RAM below minimum (${MIN_RAM_GB_FAIL} GB)"
  elif [[ "${MIN_RAM_GB_WARN:-0}" -gt 0 && "$mem_total_gb" -lt "$MIN_RAM_GB_WARN" ]]; then
    warn "RAM below warning threshold (${MIN_RAM_GB_WARN} GB)"
  fi

  local swap_total
  swap_total="$(grep -E '^SwapTotal:' /proc/meminfo | awk '{print $2}')"
  if [[ "${swap_total:-0}" -gt 0 ]]; then
    ok "Swap configured: $((swap_total / 1024)) MB"
  else
    info "No swap configured"
  fi

  if grep -q '^Hugepagesize:' /proc/meminfo; then
    local hp
    hp="$(grep -E '^HugePages_Total:' /proc/meminfo | awk '{print $2}')"
    info "HugePages total: ${hp}"
  fi

  if [[ -d /proc/sys/kernel/cma ]]; then
    info "CMA pool: $(cat /proc/sys/kernel/cma 2>/dev/null || echo n/a)"
  fi
}
