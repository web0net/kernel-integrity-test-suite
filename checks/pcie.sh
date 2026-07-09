# checks/pcie.sh
check_pcie() {
  section "PCIe"

  if ! command -v lspci &>/dev/null; then
    warn "lspci not installed — skip PCIe topology"
    return
  fi

  local dev_count
  dev_count="$(lspci 2>/dev/null | wc -l | tr -d ' ')"
  ok "PCI devices enumerated: ${dev_count}"

  if command -v lspci &>/dev/null && lspci -vv 2>/dev/null | grep -qi 'AER.*Error'; then
    warn "AER errors reported — run: lspci -vv"
  else
    ok "No AER errors in lspci -vv"
  fi

  if [[ -d /sys/kernel/iommu_groups ]]; then
    local iommu_groups
    iommu_groups="$(find /sys/kernel/iommu_groups -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$iommu_groups" -gt 0 ]]; then
      ok "IOMMU groups: ${iommu_groups}"
    else
      warn "IOMMU enabled in sysfs but no groups — check CONFIG_IOMMU"
    fi
  else
    info "No IOMMU groups in sysfs (may be expected on some ARM boards)"
  fi
}
