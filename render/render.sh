#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FROM=""
REPORT=""
TEMPLATE=""
OUTPUT=""

usage() {
  echo "Usage: render.sh --from <snapshot.json> --report <fmt> --template <name> --output <file>" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)
      FROM="$2"
      shift 2
      ;;
    --report)
      REPORT="$2"
      shift 2
      ;;
    --template)
      TEMPLATE="$2"
      shift 2
      ;;
    --output)
      OUTPUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      if [[ "$1" == *.json && -f "$1" ]]; then
        FROM="$1"
        shift
      else
        echo "Unknown argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

[[ -n "$FROM" && -n "$REPORT" && -n "$TEMPLATE" && -n "$OUTPUT" ]] || usage

if [[ ! -f "$FROM" ]]; then
  echo "Snapshot not found: $FROM" >&2
  exit 1
fi

TEMPLATE_FILE="${SCRIPT_DIR}/templates/${TEMPLATE}.${REPORT}.tpl"
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Template not found: $TEMPLATE_FILE" >&2
  exit 1
fi

_has_jq() {
  command -v jq &>/dev/null
}

# shellcheck disable=SC2034
_json_get() {
  local filter="$1"
  if _has_jq; then
    jq -r "$filter" "$FROM"
    return
  fi

  case "$filter" in
    .meta.kernel)
      _fallback_meta_string kernel
      ;;
    .meta.board)
      _fallback_meta_string board
      ;;
    .meta.hostname)
      _fallback_meta_string hostname
      ;;
    .meta.timestamp)
      _fallback_meta_string timestamp
      ;;
    .meta.profile)
      _fallback_meta_string profile
      ;;
    .summary.status)
      _fallback_summary_string status
      ;;
    .summary.pass)
      _fallback_summary_number pass
      ;;
    .summary.warn)
      _fallback_summary_number warn
      ;;
    .summary.fail)
      _fallback_summary_number fail
      ;;
    .diff.note)
      _fallback_diff_note
      ;;
    *)
      echo ""
      ;;
  esac
}

_fallback_meta_string() {
  local field="$1"
  sed -n 's/.*"meta"[[:space:]]*:[[:space:]]*{[^}]*"'"${field}"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FROM" | head -1
}

_fallback_summary_string() {
  local field="$1"
  sed -n 's/.*"summary"[[:space:]]*:[[:space:]]*{[^}]*"'"${field}"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FROM" | head -1
}

_fallback_summary_number() {
  local field="$1"
  sed -n 's/.*"summary"[[:space:]]*:[[:space:]]*{[^}]*"'"${field}"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$FROM" | head -1
}

_fallback_diff_note() {
  sed -n 's/.*"diff"[[:space:]]*:[[:space:]]*{[^}]*"note"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$FROM" | head -1
}

_build_checks_block() {
  if _has_jq; then
    if [[ "$REPORT" == "html" ]]; then
      jq -r '
        .checks
        | to_entries[]
        | "<h3>\(.key) (<span class=\"status-\(.value.status)\">\(.value.status)</span>)</h3>"
          + "<ul>"
          + ([.value.items[]? | "<li>[\(.level)] \(.message)</li>"] | join(""))
          + "</ul>"
      ' "$FROM" 2>/dev/null || echo ""
      return
    fi
    jq -r '
      .checks
      | to_entries[]
      | "### \(.key) (\(.value.status))\n"
        + ([.value.items[]? | "- [\(.level)] \(.message)"] | join("\n"))
        + "\n"
    ' "$FROM" 2>/dev/null || echo ""
    return
  fi
  echo ""
}

_build_problems_block() {
  if _has_jq; then
    if [[ "$REPORT" == "html" ]]; then
      jq -r '
        [.checks | to_entries[] | .value.items[]?
          | select(.level == "warn" or .level == "fail")
          | "<li>[\(.level)] \(.message)</li>"]
        | if length > 0 then "<ul>" + join("") + "</ul>" else "<p>(none)</p>" end
      ' "$FROM" 2>/dev/null || echo ""
      return
    fi
    jq -r '
      .checks
      | to_entries[]
      | .value.items[]?
      | select(.level == "warn" or .level == "fail")
      | "- [\(.level)] \(.message)"
    ' "$FROM" 2>/dev/null || echo ""
    return
  fi
  echo ""
}

_build_checks_detail_block() {
  if _has_jq; then
    if [[ "$REPORT" == "html" ]]; then
      jq -r '
        .checks
        | to_entries[]
        | "<article><h3>\(.key)</h3><p>Status: <strong>\(.value.status)</strong></p><ul>"
          + ([.value.items[]? | "<li><code>\(.level)</code> \(.message)</li>"] | join(""))
          + "</ul></article>"
      ' "$FROM" 2>/dev/null || echo ""
      return
    fi
    jq -r '
      .checks
      | to_entries[]
      | "#### \(.key)\n"
        + "Status: \(.value.status)\n\n"
        + ([.value.items[]? | "- `\(.level)` \(.message)"] | join("\n"))
        + "\n"
    ' "$FROM" 2>/dev/null || echo ""
    return
  fi
  echo ""
}

_build_dmesg_block() {
  if _has_jq; then
    jq -r '
      if (.artifacts.dmesg_errors // [] | length) > 0 then
        .artifacts.dmesg_errors[] | if type == "string" then . else tostring end
      else
        "(no dmesg errors captured)"
      end
    ' "$FROM" 2>/dev/null || echo ""
    return
  fi
  echo ""
}

_build_diff_detail_block() {
  if _has_jq; then
    if [[ "$REPORT" == "html" ]]; then
      jq -r '
        [
          (if .diff.previous_timestamp? then "<li>Previous run: \(.diff.previous_timestamp)</li>" else empty end),
          (if .diff.kernel_changed == true then "<li>Kernel changed (was \(.diff.previous_kernel // "unknown"))</li>" else empty end),
          (.diff.new_failures[]? | "<li>New failure [\(.check)]: \(.message)</li>"),
          (.diff.new_dmesg_errors[]? | "<li>New dmesg: \(.)</li>"),
          (.diff.resolved_failures[]? | "<li>Resolved: \(.)</li>"),
          (if (.diff.note // "") != "" then "<li>\(.diff.note)</li>" else empty end)
        ] as $lines
        | if ($lines | length) > 0 then "<ul>\($lines | join(""))</ul>" else "<p>(no diff details)</p>" end
      ' "$FROM" 2>/dev/null || echo ""
      return
    fi
    jq -r '
      [
        (if .diff.previous_timestamp? then "Previous run: \(.diff.previous_timestamp)" else empty end),
        (if .diff.kernel_changed == true then "Kernel changed (was \(.diff.previous_kernel // "unknown"))" else empty end),
        (.diff.new_failures[]? | "New failure [\(.check)]: \(.message)"),
        (.diff.new_dmesg_errors[]? | "New dmesg: \(.)"),
        (.diff.resolved_failures[]? | "Resolved: \(.)"),
        (.diff.note // empty)
      ] | .[]?
    ' "$FROM" 2>/dev/null || echo ""
    return
  fi
  echo ""
}

_esc_sed() {
  printf '%s' "$1" | sed -e 's/[&|\\]/\\&/g'
}

_apply_scalar_placeholders() {
  local line="$1"
  local k b h t p ss sp sw sf ds spath

  k="$(_esc_sed "$KERNEL")"
  b="$(_esc_sed "$BOARD")"
  h="$(_esc_sed "$HOSTNAME")"
  t="$(_esc_sed "$TIMESTAMP")"
  p="$(_esc_sed "$PROFILE")"
  ss="$(_esc_sed "$SUMMARY_STATUS")"
  sp="$(_esc_sed "$SUMMARY_PASS")"
  sw="$(_esc_sed "$SUMMARY_WARN")"
  sf="$(_esc_sed "$SUMMARY_FAIL")"
  ds="$(_esc_sed "$DIFF_SUMMARY")"
  spath="$(_esc_sed "$SNAPSHOT_PATH")"

  printf '%s' "$line" | sed \
    -e "s|{{kernel}}|${k}|g" \
    -e "s|{{board}}|${b}|g" \
    -e "s|{{hostname}}|${h}|g" \
    -e "s|{{timestamp}}|${t}|g" \
    -e "s|{{profile}}|${p}|g" \
    -e "s|{{summary_status}}|${ss}|g" \
    -e "s|{{summary_pass}}|${sp}|g" \
    -e "s|{{summary_warn}}|${sw}|g" \
    -e "s|{{summary_fail}}|${sf}|g" \
    -e "s|{{diff_summary}}|${ds}|g" \
    -e "s|{{snapshot_path}}|${spath}|g"
}

_emit_block() {
  local content="$1"
  if [[ -n "$content" ]]; then
    printf '%s' "$content"
    if [[ "$content" != *$'\n' ]]; then
      printf '\n'
    fi
  fi
}

_line_is_only_placeholder() {
  local line="$1" placeholder="$2"
  local trimmed
  trimmed="$(printf '%s' "$line" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ "$trimmed" == "{{${placeholder}}}" ]]
}

_embed_placeholder() {
  local line="$1" placeholder="$2" content="$3"
  local marker="{{${placeholder}}}"
  if [[ "$line" != *"$marker"* ]]; then
    printf '%s' "$line"
    return
  fi
  local rest="$line" out=""
  while [[ "$rest" == *"$marker"* ]]; do
    out+="${rest%%"$marker"*}"
    out+="$content"
    rest="${rest#*"$marker"}"
  done
  out+="$rest"
  printf '%s' "$out"
}

_apply_block_placeholders() {
  local line="$1"
  line="$(_embed_placeholder "$line" "checks_block" "$CHECKS_BLOCK")"
  line="$(_embed_placeholder "$line" "problems_block" "$PROBLEMS_BLOCK")"
  line="$(_embed_placeholder "$line" "checks_detail_block" "$CHECKS_DETAIL_BLOCK")"
  line="$(_embed_placeholder "$line" "dmesg_block" "$DMESG_BLOCK")"
  line="$(_embed_placeholder "$line" "diff_detail_block" "$DIFF_DETAIL_BLOCK")"
  printf '%s' "$line"
}

_write_output() {
  local line
  : >"$OUTPUT"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"

    if _line_is_only_placeholder "$line" "checks_block"; then
      _emit_block "$CHECKS_BLOCK" >>"$OUTPUT"
      continue
    fi
    if _line_is_only_placeholder "$line" "problems_block"; then
      _emit_block "$PROBLEMS_BLOCK" >>"$OUTPUT"
      continue
    fi
    if _line_is_only_placeholder "$line" "checks_detail_block"; then
      _emit_block "$CHECKS_DETAIL_BLOCK" >>"$OUTPUT"
      continue
    fi
    if _line_is_only_placeholder "$line" "dmesg_block"; then
      _emit_block "$DMESG_BLOCK" >>"$OUTPUT"
      continue
    fi
    if _line_is_only_placeholder "$line" "diff_detail_block"; then
      _emit_block "$DIFF_DETAIL_BLOCK" >>"$OUTPUT"
      continue
    fi

    line="$(_apply_scalar_placeholders "$line")"
    line="$(_apply_block_placeholders "$line")"
    printf '%s\n' "$line" >>"$OUTPUT"
  done <"$TEMPLATE_FILE"
}

_build_diff_summary() {
  if _has_jq; then
    jq -r '
      if (.diff.note // "") != "" then .diff.note
      else
        ((.diff.new_failures // []) | length) as $nf |
        ((.diff.new_dmesg_errors // []) | length) as $nd |
        if $nf == 0 and $nd == 0 then "(no changes since last run)"
        else "\($nf) new failure(s), \($nd) new dmesg error(s)"
        end
      end
    ' "$FROM" 2>/dev/null || echo ""
    return
  fi
  _json_get .diff.note
}

KERNEL="$(_json_get .meta.kernel)"
BOARD="$(_json_get .meta.board)"
HOSTNAME="$(_json_get .meta.hostname)"
TIMESTAMP="$(_json_get .meta.timestamp)"
PROFILE="$(_json_get .meta.profile)"
SUMMARY_STATUS="$(_json_get .summary.status)"
SUMMARY_PASS="$(_json_get .summary.pass)"
SUMMARY_WARN="$(_json_get .summary.warn)"
SUMMARY_FAIL="$(_json_get .summary.fail)"
DIFF_SUMMARY="$(_build_diff_summary)"
SNAPSHOT_PATH="$FROM"
CHECKS_BLOCK="$(_build_checks_block)"
PROBLEMS_BLOCK="$(_build_problems_block)"
CHECKS_DETAIL_BLOCK="$(_build_checks_detail_block)"
DMESG_BLOCK="$(_build_dmesg_block)"
DIFF_DETAIL_BLOCK="$(_build_diff_detail_block)"

_write_output
