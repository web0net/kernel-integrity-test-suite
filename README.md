# Kernel Integrity Test Suite

**Modular bash toolkit to verify system health after building, installing, and booting a custom Linux kernel.**

Run `kernel-check.sh` after `make install`, initramfs update, and reboot to confirm the new kernel is actually running, modules match, boot artifacts are present, and core subsystems (CPU, memory, storage, network, PCIe, GPU, thermal, security, scheduler, power, cgroups, tracing, virt) are working as expected. Supports platform profiles (`generic`, `sky1`), saved run history with diffs, and reports in HTML, Markdown, or JSON.

## When to run

After kernel build and install:

```bash
sudo make modules_install
sudo make install
sudo update-initramfs -u -k "$(make kernelrelease)"   # Debian/Ubuntu
sudo reboot
```

After reboot:

```bash
./kernel-check.sh --all --no-prompt --report html --template developer
```

## Usage

```bash
./kernel-check.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--all` | Run all 18 checks (default) |
| `--quick` | Kernel, boot, modules, dmesg only (CI smoke test) |
| `--kernel` … `--virt` | Run a single check section (see table below) |
| `--profile auto\|generic\|sky1` | Platform profile (default: `auto`) |
| `--json` | Print JSON summary as last line; implies `--report json` |
| `--report FORMAT` | Output report: `html`, `md`, or `json` |
| `--template NAME` | Report style: `developer` (full detail) or `community` (checklist) |
| `--no-prompt` | Skip interactive format/template prompts (defaults: `json` + `community`) |
| `--output-dir PATH` | Directory for generated reports (default: `./reports`) |
| `--history` | Compare newest vs previous snapshot and exit (needs 2+ snapshots) |
| `--history-list` | List saved snapshots under `~/.kernel-check/history` and exit |
| `--history-diff N` | JSON diff between snapshot *N* and *N+1* (1 = newest) |
| `--no-color` | Disable ANSI colors |
| `-h, --help` | Show help |

Without `--report` / `--template`, the script prompts on a TTY for format and template. In CI or scripts, use `--no-prompt` or pass both flags explicitly.

### Examples

```bash
# Full integrity check with Sky1 profile, developer HTML report
./kernel-check.sh --profile sky1 --no-prompt --report html --template developer

# Quick CI check: terminal summary + JSON line + json snapshot in ./reports
./kernel-check.sh --quick --json --no-prompt

# CI: machine-readable snapshot only (no prompts)
./kernel-check.sh --all --no-prompt --report json --template community --output-dir ./artifacts

# Only storage and network
./kernel-check.sh --storage --network --no-prompt --report md --template community

# History: list runs, then diff last two
./kernel-check.sh --history-list --no-prompt
./kernel-check.sh --history --no-prompt
./kernel-check.sh --history-diff 1 --no-prompt
```

Exit codes: `0` = all checks passed, `1` = at least one failure, `2` = script error.

## Reports and templates

Each run writes a timestamped file under `--output-dir` (default `reports/`):

| `--report` | File extension | Description |
|------------|----------------|-------------|
| `json` | `.json` | Full snapshot (meta, summary, checks, artifacts, diff vs previous run) |
| `html` | `.html` | Rendered from snapshot via `render/render.sh` |
| `md` | `.md` | Markdown for GitHub, forums, or paste bins |

| `--template` | Audience |
|--------------|----------|
| `developer` | Bug reports: checklist, problems, check details, dmesg excerpt, diff detail |
| `community` | Quick pass/warn/fail checklist and problems only |

A copy of each snapshot is also stored in `~/.kernel-check/history/` (retention default 20) for `--history` and `--history-diff`.

### Standalone rendering

Re-render any saved snapshot without re-running checks:

```bash
./render/render.sh \
  --from reports/kernel-check-2026-07-09T12-00-00+02-00.json \
  --report html \
  --template developer \
  --output report.html
```

Requires `--from`, `--report`, `--template`, and `--output`. Templates live in `render/templates/` as `{template}.{format}.tpl` (e.g. `developer.html.tpl`).

## Profiles

| Profile | Use case |
|---------|----------|
| `auto` | Detect board from devicetree (Sky1 / Orange Pi 6 → `sky1`, else `generic`) |
| `generic` | Any arm64/x86 system — no hardware-specific expectations |
| `sky1` | Orange Pi 6 Plus / CIX Sky1 — 12 CPUs, Mali-G720, dual Ethernet, SCMI sensors |

Profile files live in `profiles/`. Override thresholds, GPU patterns, and module smoke tests there. See [CONTRIBUTING.md](CONTRIBUTING.md) for adding profiles.

## Check modules

| Module | CLI flag | Validates |
|--------|----------|-----------|
| `kernel` | `--kernel` | Running kernel vs `/boot` image and `/lib/modules` tree |
| `boot` | `--boot` | Initramfs, uptime, systemd failed units, EFI |
| `modules` | `--modules` | depmod artifacts, firmware load errors, modprobe smoke |
| `dmesg` | `--dmesg` | Panics, Oops, BUG, SError, deferred probes |
| `cpu` | `--cpu` | Online CPUs, cpufreq, clocksource |
| `memory` | `--memory` | RAM, swap, hugepages |
| `storage` | `--storage` | Block devices, I/O errors |
| `network` | `--network` | Interfaces, drivers, loopback |
| `pcie` | `--pcie` | lspci topology, AER, IOMMU |
| `gpu` | `--gpu` | DRM nodes, profile GPU patterns (Panthor on Sky1) |
| `thermal` | `--thermal` | thermal_zone + SCMI hwmon |
| `security` | `--security` | LSM stack, lockdown, AppArmor |
| `scheduler` | `--scheduler` | CPU count vs profile, sched sysfs, context switches |
| `power` | `--power` | cpufreq governors, cpuidle, suspend/resume hints |
| `filesystem` | `--filesystem` | Root mount rw, fs errors in dmesg, btrfs if present |
| `cgroups` | `--cgroups` | cgroup v2 mount, controllers, systemd cgroup mode |
| `tracing` | `--tracing` | Kernel taint decode, debugfs, ftrace availability |
| `virt` | `--virt` | KVM device, CPU virt flags, virtio modules, IOMMU groups |

## Project layout

```
test-suite/
├── kernel-check.sh      # CLI entry point
├── lib/                 # common, collector, history, runner
├── checks/              # one module per subsystem (check_<name>)
├── profiles/            # platform expectations
├── render/              # render.sh + templates
├── reports/             # default report output (gitignored)
└── tests/               # bats unit tests
```

## Optional dependencies

- `lspci` — PCIe checks (`pciutils`)
- `jq` — richer snapshot diffs and template rendering (fallbacks exist)
- `vulkaninfo` — optional GPU Vulkan info (`vulkan-tools`)
- `bats` — unit tests
- `shellcheck` — static analysis

## Development

```bash
bats tests/
shellcheck kernel-check.sh lib/*.sh checks/*.sh render/render.sh
```

Extension guide: [CONTRIBUTING.md](CONTRIBUTING.md).

## Useful commands after a failed run

```bash
dmesg | grep -iE 'oops|panic|error|fail'
systemctl --failed
modprobe -n <module>
lspci -vv
```
