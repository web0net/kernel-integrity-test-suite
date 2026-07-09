# checks/power.sh
check_power() {
  section "Power"

  local gov_ok=false
  for cpu in /sys/devices/system/cpu/cpu[0-9]*; do
    [[ -d "$cpu" ]] || continue
    local id gov
    id="$(basename "$cpu")"
    [[ "$id" != "cpu0" && "$id" != "cpu4" ]] && continue
    if [[ -f "${cpu}/cpufreq/scaling_governor" ]]; then
      gov="$(read_file "${cpu}/cpufreq/scaling_governor")"
      ok "${id} scaling_governor: ${gov}"
      gov_ok=true
    fi
  done
  $gov_ok || warn "cpufreq scaling_governor not available"

  local idle_ok=false
  for cpu in /sys/devices/system/cpu/cpu0/cpuidle/state*; do
    [[ -d "$cpu" ]] || continue
    local name disabled
    name="$(read_file "${cpu}/name")"
    disabled="$(read_file "${cpu}/disable")"
    if [[ "${disabled:-0}" == "0" ]]; then
      ok "cpuidle ${name:-$(basename "$cpu")}: enabled"
      idle_ok=true
    else
      info "cpuidle ${name:-$(basename "$cpu")}: disabled"
    fi
  done
  $idle_ok || info "cpuidle states not available on cpu0"

  if [[ -r /sys/power/state ]]; then
    local states
    states="$(read_file /sys/power/state)"
    ok "Available power states: ${states}"
  else
    warn "/sys/power/state not readable — suspend/resume may be unavailable"
  fi
}
