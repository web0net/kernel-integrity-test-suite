#!/usr/bin/env bash
# shellcheck disable=SC2015
# checks/thermal.sh
check_thermal() {
  section "Temperature"

  # Generic thermal zones
  local tz_count=0
  for tz in /sys/class/thermal/thermal_zone*/; do
    [[ -d "$tz" ]] || continue
    tz_count=$((tz_count + 1))
    local type temp mc
    type="$(cat "${tz}type" 2>/dev/null || echo unknown)"
    temp="$(cat "${tz}temp" 2>/dev/null || echo 0)"
    mc=$((temp / 1000))
    info "thermal_zone $(basename "$tz"): ${type} ${mc}°C"
  done
  [[ $tz_count -gt 0 ]] && ok "Thermal zones: ${tz_count}" || info "No generic thermal zones"

  # SCMI hwmon (Sky1)
  lsmod 2>/dev/null | grep -q "scmi_hwmon" || modprobe scmi-hwmon 2>/dev/null || true

  local scmi_hw=""
  for hw in /sys/class/hwmon/hwmon*/; do
    [[ "$(cat "${hw}name" 2>/dev/null)" == "scmi_sensors" ]] && scmi_hw="$hw" && break
  done

  if [[ -n "$scmi_hw" ]]; then
    for inp in "${scmi_hw}temp"*"_input"; do
      [[ -f "$inp" ]] || continue
      local n lbl t tc
      n="$(basename "$inp" | grep -o '[0-9]*')"
      lbl="$(cat "${scmi_hw}temp${n}_label" 2>/dev/null || echo "sensor${n}")"
      t="$(cat "$inp" 2>/dev/null)"; tc=$((t / 1000))
      case "$lbl" in
        CPU_M0|CPU_M1|CPU_B0|CPU_B1)
          if [[ $tc -gt $((TEMP_CPU_FAIL / 1000)) ]]; then
            fail "${lbl}: ${tc}°C — CRITICAL"
          elif [[ $tc -gt $((TEMP_CPU_WARN / 1000)) ]]; then
            warn "${lbl}: ${tc}°C — hot"
          else
            ok "${lbl}: ${tc}°C"
          fi
          ;;
        GPU_AVE|SOC_BRC|NPU|DDR_top) ok "${lbl}: ${tc}°C" ;;
        PCB_*) info "${lbl}: ${tc}°C" ;;
      esac
    done
    info "SCMI hwmon: polling mode (notify may be unsupported on some BIOS versions)"
  else
    info "scmi_sensors hwmon not available — optional: modprobe scmi-hwmon"
  fi

  for hw in /sys/class/hwmon/hwmon*/; do
    [[ "$(cat "${hw}name" 2>/dev/null)" == "nvme" ]] || continue
    local nt
    nt="$(cat "${hw}temp1_input" 2>/dev/null)"
    [[ -n "$nt" ]] && ok "NVMe temperature: $((nt / 1000))°C"
  done
}
