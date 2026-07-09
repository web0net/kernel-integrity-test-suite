#!/usr/bin/env bash
# =============================================================================
# kernel-check.sh — Post-custom-kernel system integrity checker
#
# Usage: ./kernel-check.sh [--quick|--all|individual --flags] [--profile auto|generic|sky1]
#        ./kernel-check.sh --help
# =============================================================================

# Parse --no-color before sourcing libs (colors init at source time)
for arg in "$@"; do
  [[ "$arg" == "--no-color" ]] && export NO_COLOR=1
done

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/runner.sh
source "${SCRIPT_DIR}/lib/runner.sh"

PROFILE="auto"
JSON_OUTPUT=0
declare -A RUN=()

usage() {
  cat <<'EOF'
kernel-check.sh — Post-custom-kernel system integrity checker

Usage: ./kernel-check.sh [OPTIONS]

Options:
  --all              Run all checks (default)
  --quick            kernel + boot + modules + dmesg only
  --kernel           Kernel identity checks
  --boot             Boot artifacts and systemd
  --modules          Module tree and vermagic
  --dmesg            Kernel log severity scan
  --cpu              CPU / cpufreq / clocksource
  --memory           RAM / swap / hugepages
  --storage          Block devices and root filesystem
  --network          Network interfaces
  --pcie             PCIe topology and errors
  --gpu              DRM / GPU (profile-aware)
  --thermal          Temperature sensors
  --security         LSM and lockdown
  --profile NAME     generic | sky1 | auto (default: auto)
  --json             Machine-readable summary on stdout (last line)
  --no-color         Disable ANSI colors
  -h, --help         Show help

Exit codes: 0 = pass, 1 = failure(s), 2 = script error
EOF
  exit 0
}

_run_all() {
  RUN[kernel]=1 RUN[boot]=1 RUN[modules]=1 RUN[dmesg]=1
  RUN[cpu]=1 RUN[memory]=1 RUN[storage]=1 RUN[network]=1
  RUN[pcie]=1 RUN[gpu]=1 RUN[thermal]=1 RUN[security]=1
}

_run_quick() {
  RUN[kernel]=1 RUN[boot]=1 RUN[modules]=1 RUN[dmesg]=1
}

_run_all

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) _run_all; shift ;;
    --quick) RUN=(); _run_quick; shift ;;
    --kernel|--boot|--modules|--dmesg|--cpu|--memory|--storage|--network|--pcie|--gpu|--thermal|--security)
      RUN=()
      RUN["${1#--}"]=1
      shift
      ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --json) JSON_OUTPUT=1; shift ;;
    --no-color) NO_COLOR=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

load_profile "$PROFILE"

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}   Kernel Integrity Test Suite                  ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo -e "Kernel  : ${CYAN}$(uname -r)${NC}"
echo -e "Profile : ${CYAN}${PROFILE_NAME}${NC}"
echo -e "Board   : ${CYAN}$(read_file /sys/firmware/devicetree/base/model 2>/dev/null || echo unknown)${NC}"
echo ""

for name in kernel boot modules dmesg cpu memory storage network pcie gpu thermal security; do
  [[ -n "${RUN[$name]:-}" ]] && run_check "$name"
  echo ""
done

print_summary
