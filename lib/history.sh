#!/usr/bin/env bash
set -euo pipefail

KERNEL_CHECK_HOME="${KERNEL_CHECK_HOME:-$HOME/.kernel-check}"
HISTORY_DIR="${KERNEL_CHECK_HOME}/history"

_ensure_history_dir() {
  mkdir -p "$HISTORY_DIR"
}

save_snapshot() {
  local src="$1"
  _ensure_history_dir
  local ts dest
  ts="$(date -Iseconds 2>/dev/null | tr ':' '-')" || ts="$(date '+%Y-%m-%dT%H-%M-%S')"
  dest="${HISTORY_DIR}/${ts}.json"
  cp "$src" "$dest"
  prune_history "${HISTORY_RETENTION:-20}"
  printf '%s' "$dest"
}

list_snapshots() {
  _ensure_history_dir
  find "$HISTORY_DIR" -maxdepth 1 -name '*.json' -print 2>/dev/null \
    | sort -r
}

get_snapshot_by_index() {
  local n="$1"
  list_snapshots | sed -n "${n}p"
}

prune_history() {
  local keep="$1"
  local i=0
  local file
  while IFS= read -r file; do
    i=$((i + 1))
    if [[ $i -gt $keep ]]; then
      rm -f "$file"
    fi
  done < <(list_snapshots)
}

_has_jq() { command -v jq &>/dev/null; }

compute_diff() {
  local prev="$1" cur="$2"
  if _has_jq; then
    _compute_diff_jq "$prev" "$cur"
  else
    _compute_diff_bash "$prev" "$cur"
  fi
}

_compute_diff_jq() {
  local prev="$1" cur="$2"
  jq -n \
    --slurpfile p "$prev" --slurpfile c "$cur" \
    '{
      previous_timestamp: $p[0].meta.timestamp,
      previous_kernel: $p[0].meta.kernel,
      kernel_changed: ($p[0].meta.kernel != $c[0].meta.kernel),
      new_failures: [
        $c[0].checks | to_entries[] |
        select(.value.status == "fail") |
        select(($p[0].checks[.key].status // "pass") != "fail") |
        {check: .key, message: (.value.items[] | select(.level=="fail") | .message)}
      ],
      resolved_failures: [
        $p[0].checks | to_entries[] |
        select(.value.status == "fail") |
        select(($c[0].checks[.key].status // "pass") != "fail") |
        {check: .key, message: (.value.items[] | select(.level=="fail") | .message)}
      ],
      new_dmesg_errors: (
        ($c[0].artifacts.dmesg_errors // []) - ($p[0].artifacts.dmesg_errors // [])
      ),
      added_modules: (
        ($c[0].artifacts.loaded_modules // []) - ($p[0].artifacts.loaded_modules // [])
      ),
      removed_modules: (
        ($p[0].artifacts.loaded_modules // []) - ($c[0].artifacts.loaded_modules // [])
      )
    }'
}

_compute_diff_bash() {
  local prev_k cur_k changed=false
  prev_k="$(grep -o '"kernel"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" | head -1)"
  cur_k="$(grep -o '"kernel"[[:space:]]*:[[:space:]]*"[^"]*"' "$2" | head -1)"
  [[ "$prev_k" != "$cur_k" ]] && changed=true
  printf '{"kernel_changed":%s,"new_failures":[],"new_dmesg_errors":[],"resolved_failures":[]}' \
    "$changed"
}
