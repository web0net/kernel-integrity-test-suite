# Kernel Integrity Test Suite

**Modular bash toolkit to verify system health after building, installing, and booting a custom Linux kernel.**

Run `kernel-check.sh` after `make install`, initramfs update, and reboot to confirm the new kernel is actually running, modules match, boot artifacts are present, and core subsystems (CPU, memory, storage, network, PCIe, GPU, thermal, security) are working as expected. Supports platform profiles (`generic`, `sky1`) and CI-friendly JSON output.

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
./kernel-check.sh --all
```

## Usage

```bash
./kernel-check.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--all` | Run all checks (default) |
| `--quick` | Kernel, boot, modules, dmesg only (CI smoke test) |
| `--kernel` … `--security` | Run a single check section |
| `--profile auto\|generic\|sky1` | Platform profile (default: `auto`) |
| `--json` | Print JSON summary as last line |
| `--no-color` | Disable ANSI colors |
| `-h, --help` | Show help |

### Examples

```bash
# Full integrity check with Sky1 profile
./kernel-check.sh --profile sky1

# Quick CI check with JSON output
./kernel-check.sh --quick --json

# Only storage and network
./kernel-check.sh --storage --network
```

Exit codes: `0` = all checks passed, `1` = at least one failure, `2` = script error.

## Profiles

| Profile | Use case |
|---------|----------|
| `auto` | Detect board from devicetree (Sky1 / Orange Pi 6 → `sky1`, else `generic`) |
| `generic` | Any arm64/x86 system — no hardware-specific expectations |
| `sky1` | Orange Pi 6 Plus / CIX Sky1 — 12 CPUs, Mali-G720, dual Ethernet, SCMI sensors |

Profile files live in `profiles/`. Override thresholds, GPU patterns, and module smoke tests there.

## Check modules

| Module | Validates |
|--------|-----------|
| `kernel` | Running kernel vs `/boot` image and `/lib/modules` tree |
| `boot` | Initramfs, uptime, systemd failed units, EFI |
| `modules` | depmod artifacts, firmware load errors, modprobe smoke |
| `dmesg` | Panics, Oops, BUG, SError, deferred probes |
| `cpu` | Online CPUs, cpufreq, clocksource |
| `memory` | RAM, swap, hugepages |
| `storage` | Root mount rw, block devices, I/O errors |
| `network` | Interfaces, drivers, loopback |
| `pcie` | lspci topology, AER, IOMMU |
| `gpu` | DRM nodes, profile GPU patterns (Panthor on Sky1) |
| `thermal` | thermal_zone + SCMI hwmon |
| `security` | LSM stack, lockdown, AppArmor |

## Project layout

```
test-suite/
├── kernel-check.sh   # CLI entry point
├── lib/              # common helpers + runner
├── checks/           # one module per subsystem
├── profiles/         # platform expectations
└── tests/            # bats unit tests
```

## Optional dependencies

- `lspci` — PCIe checks (`pciutils`)
- `vulkaninfo` — optional GPU Vulkan info (`vulkan-tools`)
- `bats` — unit tests
- `shellcheck` — static analysis

## Development

```bash
bats tests/test_common.bats
shellcheck kernel-check.sh lib/*.sh checks/*.sh
```

## Useful commands after a failed run

```bash
dmesg | grep -iE 'oops|panic|error|fail'
systemctl --failed
modprobe -n <module>
lspci -vv
```
