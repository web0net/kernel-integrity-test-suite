#!/usr/bin/env bash
# checks/scheduler.sh
check_scheduler() {
  section "Scheduler"

  local nproc_val
  nproc_val="$(nproc 2>/dev/null || echo 0)"
  if [[ "${nproc_val:-0}" -gt 0 ]]; then
    ok "Online CPUs (nproc): ${nproc_val}"
  else
    fail "Could not determine online CPU count"
  fi

  if [[ "${EXPECTED_CPU_COUNT:-0}" -gt 0 ]]; then
    if [[ "$nproc_val" -eq "$EXPECTED_CPU_COUNT" ]]; then
      ok "CPU count matches profile (${EXPECTED_CPU_COUNT})"
    else
      fail "Expected ${EXPECTED_CPU_COUNT} online CPUs, got ${nproc_val}"
    fi
  fi

  if [[ -r /proc/sys/kernel/sched_latency_ns ]]; then
    local latency
    latency="$(read_file /proc/sys/kernel/sched_latency_ns)"
    ok "sched_latency_ns: ${latency}"
  else
    info "sched_latency_ns not exposed in sysfs"
  fi

  if [[ -r /proc/stat ]]; then
    local ctxt
    ctxt="$(awk '/^ctxt / {print $2}' /proc/stat)"
    if [[ -n "${ctxt:-}" ]]; then
      ok "Context switches (ctxt): ${ctxt}"
    else
      warn "ctxt counter not found in /proc/stat"
    fi
  else
    warn "/proc/stat not readable"
  fi

  local version
  version="$(read_file /proc/version)"
  if [[ "$version" == *PREEMPT_RT* ]]; then
    ok "Preempt model: PREEMPT_RT"
  elif [[ "$version" == *PREEMPT_DYNAMIC* ]]; then
    ok "Preempt model: PREEMPT_DYNAMIC"
  elif [[ "$version" == *PREEMPT* ]]; then
    ok "Preempt model: voluntary/full PREEMPT kernel"
  elif [[ "$version" == *SMP* ]]; then
    info "Preempt model: likely non-preempt or voluntary (no PREEMPT in version string)"
  else
    info "Preempt model: unknown (${version})"
  fi
}
