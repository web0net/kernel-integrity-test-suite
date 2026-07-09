#!/usr/bin/env bash
# shellcheck disable=SC2015
# checks/security.sh
check_security() {
  section "Security"

  if [[ -r /sys/kernel/security/lsm ]]; then
    ok "LSM stack: $(cat /sys/kernel/security/lsm)"
  else
    info "LSM sysfs not available"
  fi

  if [[ -r /sys/kernel/security/lockdown ]]; then
    local mode
    mode="$(cat /sys/kernel/security/lockdown 2>/dev/null || echo unknown)"
    info "Kernel lockdown: ${mode}"
  fi

  if grep -q '^flags\s*:.*\bnoinitrd\b' /proc/cpuinfo 2>/dev/null; then
    info "KASLR status: inspect /proc/cmdline and kernel config"
  fi

  if command -v aa-status &>/dev/null; then
    aa-status --enabled 2>/dev/null && ok "AppArmor enabled" || info "AppArmor disabled"
  fi
}
