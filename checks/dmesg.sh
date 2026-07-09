#!/usr/bin/env bash
# shellcheck disable=SC2015
check_dmesg() {
  section "Kernel Log (dmesg)"

  local log
  log="$(dmesg 2>/dev/null || true)"

  _dmesg_count() { echo "$log" | grep -ciE -- "$1" || true; }

  local oops bugs panics serrors deferred
  oops="$(_dmesg_count 'Oops:|BUG:|Unable to handle kernel')"
  bugs="$(_dmesg_count '------------\[ cut here \]')"
  panics="$(_dmesg_count 'Kernel panic')"
  serrors="$(_dmesg_count 'Asynchronous SError|SError Interrupt')"
  deferred="$(_dmesg_count 'deferred probe pending')"

  [[ "$panics" == "0" ]] && ok "No kernel panics in dmesg" || fail "Kernel panic(s) in dmesg: ${panics}"
  [[ "$oops" == "0" ]]   && ok "No Oops in dmesg" || fail "Oops detected in dmesg: ${oops}"
  [[ "$bugs" == "0" ]]   && ok "No BUG warnings in dmesg" || fail "BUG() in dmesg: ${bugs}"
  [[ "$serrors" == "0" ]] && ok "No SError in dmesg" || fail "SError in dmesg: ${serrors}"

  if [[ "$deferred" == "0" ]]; then
    ok "No deferred probe pending"
  else
    warn "Deferred probes pending: ${deferred} — driver or dependency issue"
  fi

  local err_count
  err_count="$(echo "$log" | grep -ciE '\berror\b|\bfail\b' || true)"
  info "dmesg lines matching error/fail (informational): ${err_count}"

  local errors
  errors="$(echo "$log" | grep -iE 'error|fail|oops|panic|warn' | tail -50 || true)"
  set_artifact "dmesg_errors" "$errors"
}
