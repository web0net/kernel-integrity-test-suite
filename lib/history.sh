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
