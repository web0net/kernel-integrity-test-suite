#!/usr/bin/env bash

# GPU-related module name patterns (kernel DRM/GPU drivers)
GPU_MODULE_PATTERN='^(panthor|mali|amdgpu|radeon|i915|i965|nouveau|virtio_gpu|vgem|drm)'

normalize_drm_driver() {
  local driver_path="$1"
  [[ -r "$driver_path" ]] || { echo ""; return; }
  if [[ -L "$driver_path" ]]; then
    basename "$(readlink -f "$driver_path" 2>/dev/null || readlink "$driver_path")"
  else
    tr -d '\0' < "$driver_path"
  fi
}

parse_modinfo_version() {
  local file="$1"
  [[ -r "$file" ]] || { echo ""; return; }
  sed -n 's/^version:[[:space:]]*//p' "$file" | head -1
}

parse_modinfo_description() {
  local file="$1"
  [[ -r "$file" ]] || { echo ""; return; }
  sed -n 's/^description:[[:space:]]*//p' "$file" | head -1
}

gpu_module_grep() {
  local lsmod_text="$1"
  printf '%b\n' "$lsmod_text" | awk '$1 != "Module" && NF {print $1}' | grep -E "$GPU_MODULE_PATTERN" || true
}

collect_drm_drivers() {
  local drm_sysfs="${1:-/sys/class/drm}"
  local driver path drivers=""
  for path in "${drm_sysfs}"/card[0-9]*; do
    [[ -d "$path/device" ]] || continue
    driver="$(normalize_drm_driver "$path/device/driver" 2>/dev/null || true)"
    [[ -n "$driver" ]] && drivers+="${driver} "
  done
  printf '%s' "${drivers%" "}"
}
