#!/usr/bin/env bash
# Copyright (C) 2026 webnetbt@gmail.com
# SPDX-License-Identifier: GPL-2.0-or-later
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
REPORT_FORMAT=""
REPORT_TEMPLATE=""
NO_PROMPT=0
OUTPUT_DIR="${SCRIPT_DIR}/reports"
HISTORY_ONLY=0
HISTORY_LIST=0
HISTORY_DIFF_N=0
LIMITED_ACCESS=false
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
  --audio            ALSA cards, snd modules, audio dmesg
  --thermal          Temperature sensors
  --security         LSM and lockdown
  --scheduler        Scheduler and CPU topology
  --power            cpufreq, cpuidle, suspend states
  --filesystem       Root mount, fs errors, btrfs
  --cgroups          cgroup v2 and controllers
  --tracing          Taint decode, debugfs, ftrace
  --virt             KVM, virtio, IOMMU groups
  --profile NAME     generic | sky1 | auto (default: auto)
  --json             Machine-readable summary on stdout (last line)
  --report FORMAT    html | md | json
  --template NAME    developer | community
  --no-prompt        Skip interactive prompts (default: json + community)
  --output-dir PATH  Report output directory
  --history          Show diff vs last snapshot and exit
  --history-list     List saved snapshots and exit
  --history-diff N   Diff vs N-th snapshot (1=newest)
  --no-color         Disable ANSI colors
  -h, --help         Show help

Exit codes: 0 = pass, 1 = failure(s), 2 = script error
EOF
  exit 0
}

_prompt_report_format() {
  echo "Select report format:" >&2
  echo "  1) HTML       (browser-friendly)" >&2
  echo "  2) Markdown   (GitHub, forums)" >&2
  echo "  3) JSON       (machine-readable)" >&2
  local choice
  read -r -p "Choice [1-3]: " choice </dev/tty || choice="3"
  case "$choice" in
    1) REPORT_FORMAT="html" ;;
    2) REPORT_FORMAT="md" ;;
    3|"") REPORT_FORMAT="json" ;;
    *) echo "Invalid choice" >&2; exit 2 ;;
  esac
}

_prompt_template() {
  echo "Select report template:" >&2
  echo "  1) Developer  (full details for bug reports)" >&2
  echo "  2) Community  (quick checklist)" >&2
  local choice
  read -r -p "Choice [1-2]: " choice </dev/tty || choice="2"
  case "$choice" in
    1) REPORT_TEMPLATE="developer" ;;
    2|"") REPORT_TEMPLATE="community" ;;
    *) echo "Invalid choice" >&2; exit 2 ;;
  esac
}

_resolve_report_options() {
  if [[ "$HISTORY_LIST" -eq 1 ]]; then
    list_snapshots
    exit 0
  fi
  if [[ "$NO_PROMPT" -eq 1 ]]; then
    [[ -z "$REPORT_FORMAT" ]] && REPORT_FORMAT="json"
    [[ -z "$REPORT_TEMPLATE" ]] && REPORT_TEMPLATE="community"
  else
    [[ -z "$REPORT_FORMAT" ]] && _prompt_report_format
    [[ -z "$REPORT_TEMPLATE" ]] && _prompt_template
  fi
  export REPORT_FORMAT REPORT_TEMPLATE
}

_handle_history_only() {
  local newest second
  newest="$(list_snapshots | sed -n '1p')"
  second="$(list_snapshots | sed -n '2p')"
  if [[ -z "$newest" || -z "$second" ]]; then
    echo "Need at least 2 snapshots for --history" >&2
    exit 2
  fi
  compute_diff "$second" "$newest"
  exit 0
}

_handle_history_diff() {
  local n="$1"
  local cur prev
  cur="$(get_snapshot_by_index "$n")"
  prev="$(get_snapshot_by_index $((n + 1)))"
  if [[ -z "$cur" ]]; then
    echo "No snapshot at index ${n}" >&2
    exit 2
  fi
  if [[ -z "$prev" ]]; then
    printf '%s\n' '{"note":"No previous snapshot available"}'
    exit 0
  fi
  compute_diff "$prev" "$cur"
  exit 0
}

_run_all() {
  RUN[kernel]=1 RUN[boot]=1 RUN[modules]=1 RUN[dmesg]=1
  RUN[cpu]=1 RUN[memory]=1 RUN[storage]=1 RUN[network]=1
  RUN[pcie]=1 RUN[gpu]=1 RUN[audio]=1 RUN[thermal]=1 RUN[security]=1
  RUN[scheduler]=1 RUN[power]=1 RUN[filesystem]=1 RUN[cgroups]=1
  RUN[tracing]=1 RUN[virt]=1
}

_run_quick() {
  RUN[kernel]=1 RUN[boot]=1 RUN[modules]=1 RUN[dmesg]=1
}

_run_all

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) _run_all; shift ;;
    --quick) RUN=(); _run_quick; shift ;;
    --kernel|--boot|--modules|--dmesg|--cpu|--memory|--storage|--network|--pcie|--gpu|--audio|--thermal|--security|--scheduler|--power|--filesystem|--cgroups|--tracing|--virt)
      RUN=()
      RUN["${1#--}"]=1
      shift
      ;;
    --profile) PROFILE="$2"; shift 2 ;;
    --report) REPORT_FORMAT="$2"; shift 2 ;;
    --template) REPORT_TEMPLATE="$2"; shift 2 ;;
    --no-prompt) NO_PROMPT=1; shift ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --history) HISTORY_ONLY=1; shift ;;
    --history-list) HISTORY_LIST=1; shift ;;
    --history-diff) HISTORY_DIFF_N="$2"; shift 2 ;;
    --json) JSON_OUTPUT=1; REPORT_FORMAT="json"; shift ;;
    --no-color) NO_COLOR=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ "$HISTORY_LIST" -eq 1 ]]; then
  _resolve_report_options
fi

load_profile "$PROFILE"

if [[ "$HISTORY_ONLY" -eq 1 ]]; then
  _handle_history_only
fi

if [[ "$HISTORY_DIFF_N" -gt 0 ]]; then
  _handle_history_diff "$HISTORY_DIFF_N"
fi

_resolve_report_options

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}   Kernel Integrity Test Suite                  ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo -e "Kernel  : ${CYAN}$(uname -r)${NC}"
echo -e "Profile : ${CYAN}${PROFILE_NAME}${NC}"
echo -e "Board   : ${CYAN}$(read_file /sys/firmware/devicetree/base/model 2>/dev/null || echo unknown)${NC}"
echo ""

init_collector

if ! dmesg &>/dev/null; then
  LIMITED_ACCESS=true
  export LIMITED_ACCESS
  warn "Limited access: dmesg requires root or group membership"
fi

for name in kernel boot modules dmesg cpu memory storage network pcie gpu audio thermal security scheduler power filesystem cgroups tracing virt; do
  [[ -n "${RUN[$name]:-}" ]] && run_check "$name"
  echo ""
done

PREV_SNAPSHOT="$(list_snapshots | head -1 || true)"
SNAPSHOT_TMP="$(mktemp)"
DIFF_JSON=$(printf '%s' '{}')
export DIFF_JSON
flush_snapshot "$SNAPSHOT_TMP"

if [[ -n "$PREV_SNAPSHOT" && -f "$PREV_SNAPSHOT" ]]; then
  DIFF_JSON="$(compute_diff "$PREV_SNAPSHOT" "$SNAPSHOT_TMP")"
else
  DIFF_JSON=$(printf '%s' '{"note":"No previous snapshot available"}')
fi
export DIFF_JSON
flush_snapshot "$SNAPSHOT_TMP"

mkdir -p "$OUTPUT_DIR"
REPORT_FILE="${OUTPUT_DIR}/kernel-check-$(date -Iseconds 2>/dev/null | tr ':' '-' || date '+%Y-%m-%dT%H-%M-%S').${REPORT_FORMAT}"

if [[ "$REPORT_FORMAT" == "json" ]]; then
  cp "$SNAPSHOT_TMP" "$REPORT_FILE"
elif [[ "$REPORT_FORMAT" == "html" || "$REPORT_FORMAT" == "md" ]]; then
  "${SCRIPT_DIR}/render/render.sh" --from "$SNAPSHOT_TMP" \
    --report "$REPORT_FORMAT" --template "$REPORT_TEMPLATE" \
    --output "$REPORT_FILE" || exit 2
else
  echo "Unknown report format: ${REPORT_FORMAT}" >&2
  exit 2
fi

HISTORY_PATH="$(save_snapshot "$SNAPSHOT_TMP")"

echo ""
info "Report saved: ${REPORT_FILE}"
info "History snapshot: ${HISTORY_PATH}"
rm -f "$SNAPSHOT_TMP"

print_summary
