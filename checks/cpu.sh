#!/usr/bin/env bash
# checks/cpu.sh
check_cpu() {
  section "CPU"

  local online nproc_val
  online="$(grep -c '^processor' /proc/cpuinfo)"
  nproc_val="$(nproc)"
  ok "CPUs online: ${nproc_val} (cpuinfo entries: ${online})"

  if [[ "${EXPECTED_CPU_COUNT:-0}" -gt 0 ]]; then
    if [[ "$nproc_val" -eq "$EXPECTED_CPU_COUNT" ]]; then
      ok "CPU count matches profile (${EXPECTED_CPU_COUNT})"
    else
      fail "Expected ${EXPECTED_CPU_COUNT} CPUs, got ${nproc_val}"
    fi
  fi

  local cpu_ok=false
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    [[ -d "$cpu" ]] || continue
    local id freq gov
    id="$(basename "$cpu")"
    [[ "$id" =~ cpu[0-9]+ ]] || continue
    # sample first cluster cpu only: cpu0 and cpu4 if exist
    [[ "$id" != "cpu0" && "$id" != "cpu4" ]] && continue
    if [[ -f "${cpu}/cpufreq/scaling_cur_freq" ]]; then
      freq="$(cat "${cpu}/cpufreq/scaling_cur_freq")"
      gov="$(cat "${cpu}/cpufreq/scaling_governor" 2>/dev/null || echo unknown)"
      if [[ "${freq:-0}" -gt 0 ]]; then
        ok "${id}: $((freq / 1000)) MHz (governor: ${gov})"
        cpu_ok=true
      fi
    fi
  done
  $cpu_ok || warn "cpufreq not available — try: modprobe cpufreq_dt or scmi-cpufreq"

  local clk
  clk="$(cat /sys/devices/system/clocksource/clocksource0/current_clocksource 2>/dev/null || echo unknown)"
  if [[ "$clk" != "jiffies" && "$clk" != "unknown" ]]; then
    ok "Clocksource: ${clk}"
  else
    warn "Clocksource is ${clk} — timer subsystem may be misconfigured"
  fi
}
