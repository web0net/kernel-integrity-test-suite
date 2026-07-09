# checks/virt.sh
check_virt() {
  section "Virtualization"

  if [[ -e /dev/kvm ]]; then
    if [[ -r /dev/kvm && -w /dev/kvm ]]; then
      ok "/dev/kvm present and accessible"
    else
      warn "/dev/kvm present but not readable/writable — add user to kvm group or use root"
    fi
  else
    info "/dev/kvm not present (KVM may be disabled or unavailable on this host)"
  fi

  if grep -qE '\b(vmx|svm)\b' /proc/cpuinfo 2>/dev/null; then
    local flag
    flag="$(grep -m1 -oE 'vmx|svm' /proc/cpuinfo)"
    ok "Hardware virtualization flag in cpuinfo: ${flag}"
  else
    info "No vmx/svm in cpuinfo — nested/host virt may be unavailable"
  fi

  local virtio
  virtio="$(lsmod 2>/dev/null | awk '{print $1}' | grep -E '^virtio_' | tr '\n' ' ' | sed 's/ $//' || true)"
  if [[ -n "$virtio" ]]; then
    ok "virtio modules loaded: ${virtio}"
  else
    info "No virtio_* modules loaded (expected on bare metal without guests)"
  fi

  local iommu_count=0
  if [[ -d /sys/kernel/iommu_groups ]]; then
    iommu_count="$(find /sys/kernel/iommu_groups -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${iommu_count:-0}" -gt 0 ]]; then
      ok "IOMMU groups: ${iommu_count}"
    else
      info "IOMMU groups directory empty — IOMMU may be disabled"
    fi
  else
    warn "IOMMU groups sysfs missing"
  fi
}
