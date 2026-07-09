# Contributing

How to extend the Kernel Integrity Test Suite with new platform profiles, check modules, and report templates.

## Adding a profile

1. Create `profiles/<name>.conf` (bash-assignable variables, no executable logic required).
2. Set thresholds and expectations used by checks, for example:

   ```bash
   MIN_RAM_GB_WARN=1
   MIN_RAM_GB_FAIL=0
   EXPECTED_CPU_COUNT=0
   GPU_DMESG_PATTERN=""
   MIN_ETH_INTERFACES=0
   TEMP_CPU_WARN=70000
   TEMP_CPU_FAIL=85000
   MODULE_SMOKE_TEST=""
   ```

3. Wire the name into `load_profile()` in `lib/runner.sh` if you need non–devicetree auto-detection, or document that users pass `--profile <name>`.
4. Add a row to the Profiles table in `README.md`.

Use `profiles/generic.conf` and `profiles/sky1.conf` as references. Checks read these variables after `load_profile` runs; unset variables should behave safely (most checks treat `0` or empty as “skip strict match”).

## Adding a check module

Checks follow a strict naming convention so `run_check` can load and invoke them.

| Piece | Convention |
|-------|------------|
| File | `checks/<name>.sh` |
| Entry function | `check_<name>()` |
| CLI | `--<name>` in `kernel-check.sh` |
| Full run | Add `<name>` to `_run_all()` and the `for name in …` loop in `kernel-check.sh` |

### Minimal module skeleton

```bash
# checks/example.sh
check_example() {
  section "Example"

  if some_condition; then
    ok "Something good"
  else
    warn "Something suspicious"
  fi
}
```

`run_check` sets `CHECK_CATEGORY=<name>` before sourcing your file and calling `check_<name>`. While `CHECK_CATEGORY` is set, the helpers in `lib/common.sh` record results automatically:

- `ok "message"` → pass
- `warn "message"` → warn
- `fail "message"` → fail
- `info "message"` → console only (not recorded in snapshot)

Use `section "Title"` for terminal grouping. Prefer profile variables from `profiles/*.conf` instead of hard-coding board-specific values.

### Collector API (`lib/collector.sh`)

For custom recording (outside `ok`/`warn`/`fail`), call:

```bash
record_check CATEGORY LEVEL MESSAGE
```

| Argument | Values |
|----------|--------|
| `CATEGORY` | Usually matches module name (same as `CHECK_CATEGORY`) |
| `LEVEL` | `pass`, `warn`, or `fail` |
| `MESSAGE` | Plain text; escaped for JSON automatically |

Category status is derived from items: any `fail` → category `fail`; else any `warn` → `warn`; else `pass`.

Attach large optional blobs (shown in developer templates / artifacts section of JSON):

```bash
set_artifact KEY VALUE
```

Example from a check module:

```bash
set_artifact dmesg_excerpt "$(dmesg | tail -50)"
```

Snapshots are built in `flush_snapshot()` with `meta`, `summary`, `checks`, `artifacts`, and `diff`.

## Report templates

Templates are plain text files: `render/templates/{developer|community}.{html|md}.tpl`.

`render/render.sh` reads a snapshot JSON and substitutes placeholders. Scalar fields come from snapshot `meta` and `summary`; block placeholders are generated from `checks`, `artifacts`, and `diff`.

### Scalar placeholders

| Placeholder | Source |
|-------------|--------|
| `{{kernel}}` | `meta.kernel` |
| `{{board}}` | `meta.board` |
| `{{hostname}}` | `meta.hostname` |
| `{{timestamp}}` | `meta.timestamp` |
| `{{profile}}` | `meta.profile` |
| `{{summary_status}}` | `summary.status` |
| `{{summary_pass}}` | `summary.pass` |
| `{{summary_warn}}` | `summary.warn` |
| `{{summary_fail}}` | `summary.fail` |
| `{{diff_summary}}` | Human-readable diff summary from `diff` |
| `{{snapshot_path}}` | Path to the `--from` snapshot file |

### Block placeholders

| Placeholder | Content |
|-------------|---------|
| `{{checks_block}}` | Summary table/list of categories and status |
| `{{problems_block}}` | Warn/fail items only |
| `{{checks_detail_block}}` | All items per category (developer templates) |
| `{{dmesg_block}}` | `artifacts.dmesg_excerpt` or similar |
| `{{diff_detail_block}}` | Detailed diff vs previous snapshot |

To add a new block placeholder, extend `render/render.sh` (search for `{{checks_block}}`) and add the marker to the appropriate `.tpl` files.

### Testing changes

```bash
bats tests/test_render.bats tests/test_collector.bats
./render/render.sh --from tests/fixtures/sample-snapshot.json \
  --report md --template developer --output /tmp/out.md
shellcheck checks/newmodule.sh
```

## Pull requests

- Keep checks read-only on the system except where unavoidable.
- Run `shellcheck` on touched shell scripts.
- Update `README.md` check table and CLI help in `kernel-check.sh` when adding flags or modules.
