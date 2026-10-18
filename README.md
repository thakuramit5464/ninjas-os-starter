# Ninjas OS

A fully scripted, Arch-based Linux distribution. Alpha 0.1 ("Shuriken") is a
bootable KDE Plasma live ISO built with Archiso. Later milestones add branding
and a local-first, permission-controlled AI desktop assistant.

**Status:** build pipeline implemented and unit-tested. The ISO has **not yet
been built or boot-tested** by the maintainers of this commit; see
[Verification status](#verification-status).

## How it works

```
/usr/share/archiso/configs/releng   (upstream, never modified)
            │  scripts/prepare-profile.sh
            ▼
work/profile/                       (generated, git-ignored)
  ├─ packages.x86_64   = upstream list − config/packages.remove.x86_64
  │                      + config/packages.extra.x86_64
  ├─ airootfs/         = upstream airootfs
  │                      − config/upstream-units-disable
  │                      + profile-overlay/airootfs/  (regular files)
  │                      + profile-overlay/templates/ (rendered)
  │                      + config/airootfs-symlinks   (service enablement)
  └─ profiledef.sh     = upstream + appended Ninjas OS overrides
            │  scripts/build-iso.sh  →  sudo mkarchiso
            ▼
out/ninjas-os-<version>.<date>-x86_64.iso  (+ .sha256, .pkglist.txt, .build-info.txt)
```

Everything that makes the image "Ninjas OS" lives in `config/` and
`profile-overlay/`. The upstream `releng` profile and its boot configuration
(syslinux for BIOS, systemd-boot for UEFI) are copied, not edited.

## Requirements

- An **Arch Linux virtual machine** (x86_64) with ~20 GiB free disk, 6-8 GiB RAM.
  Windows is the host only; the build does not run on Windows or WSL.
- `archiso` (provides `mkarchiso` and the `releng` profile), `git`, `sudo`
  for your user.
- A disposable VM (VirtualBox, QEMU, ...) to boot the result.

## Quick start (inside the Arch VM)

```bash
sudo pacman -Syu
sudo pacman -S --needed archiso git shellcheck
git clone https://github.com/thakuramit5464/ninjas-os-starter.git ninjas-os
cd ninjas-os

tests/run-all.sh                       # static checks + profile preparation test (no root)
scripts/check-prereqs.sh --packages    # tools, profile, disk, and package names
scripts/build-iso.sh                   # prepare profile, run mkarchiso, write out/
```

`build-iso.sh` runs as your normal user and calls `sudo` only for `mkarchiso`
and for removing the root-owned `work/build` directory. Output goes to `out/`
only. Nothing is ever written to a physical disk.

Then follow [docs/vm-testing.md](docs/vm-testing.md) to boot the ISO in a
disposable VM.

## Scripts

| Script | Purpose |
| --- | --- |
| `scripts/check-prereqs.sh [--packages]` | Validate host, tools, upstream profile, disk/RAM; optionally every package name via `pacman -Si`. |
| `scripts/prepare-profile.sh` | Build `work/profile` from upstream `releng` + this repo. Idempotent. Proves upstream is unchanged. |
| `scripts/build-iso.sh [--dry-run] [--skip-prepare] [--keep-build-dir]` | Run the whole pipeline and write ISO + checksum + manifest + build info to `out/`. |
| `scripts/clean.sh [--out] [--dry-run]` | Remove `work/` (and `out/`). Refuses any path outside those directories. |
| `tests/run-all.sh` | All checks that need neither root nor Archiso. |

## What is in the image

- Upstream Archiso `releng` live system (kernel, firmware, rescue tools, sshd,
  cloud-init, VM guest agents).
- KDE Plasma 6 (`plasma-meta`) on **Wayland**, SDDM, Konsole, Dolphin, Ark,
  Kate, PipeWire audio, Noto/DejaVu fonts.
- NetworkManager (replaces upstream systemd-networkd + iwd enablement).
- `virtualbox-guest-utils` (graphical variant) instead of upstream `-nox`.
- A live user `ninja` with no password and passwordless sudo, auto-logged into
  Plasma. Created at boot by `ninjas-live-setup.service`.
- Ninjas OS identity in `/etc/os-release`, `/etc/issue`, `/etc/motd`,
  `/etc/hostname`, `/etc/ninjas-os-release`, and a desktop welcome file.

Every deviation from upstream is listed with its reason in
[docs/upstream-deviations.md](docs/upstream-deviations.md).

## Verification status

| Check | Where | Result |
| --- | --- | --- |
| `bash -n`, shellcheck, overlay/config lint (`tests/run-static-checks.sh`) | Windows Git Bash, 2026-10-16 | passed |
| Profile preparation against fixture upstream (`tests/test-prepare-profile.sh`) | Windows Git Bash, 2026-10-16 | passed (symlink assertions skipped: host cannot create symlinks) |
| Package names exist in Arch repos | archlinux.org package pages, 2026-10-16 | verified manually for plasma-meta, sddm, networkmanager, virtualbox-guest-utils; **re-verify with `check-prereqs.sh --packages`** |
| `scripts/build-iso.sh` produces an ISO | Arch VM | **not yet run** |
| ISO boots to Plasma in a VM | disposable VM | **not yet run** |

## Rolling-release caveat

Arch Linux has no fixed releases. Package names, the upstream `releng`
profile, and desktop behaviour change over time; a build that works today may
need a config tweak next month. The scripts record the Archiso version,
timestamp (`SOURCE_DATE_EPOCH`), git revision, and full package manifest for
every build, but **bit-for-bit reproducible output is not a goal** unless you
pin a mirror snapshot (for example an Arch Linux Archive date) in the
profile's `pacman.conf`.

Known example: Plasma 6.8 (October 2026) removed the X11 session; the original
starter's `plasma-x11-session` entry would now fail `pacstrap`.

## Security notes

- The live image is for isolated testing. `ninja` has passwordless sudo, root
  has an empty password on the consoles, and upstream enables `sshd`. Do not
  expose the VM to untrusted networks.
- The future AI agent will be an unprivileged user-space process behind a
  deny-by-default policy engine. It will never run arbitrary model-generated
  shell commands. See [docs/ai-architecture.md](docs/ai-architecture.md).
- Writing the ISO to a USB device is a manual step with explicit target
  verification; see [docs/vm-testing.md](docs/vm-testing.md#usb-later).

## Repository layout

```
.
├── CLAUDE.md                     # instructions for Claude Code
├── .specify/memory/constitution.md
├── specs/001-ninjas-os-foundation/{spec,plan,tasks}.md
├── prompts/                      # spec-kit style prompts
├── config/
│   ├── ninjas-os.conf            # name, version, codename, ISO metadata, live user
│   ├── packages.extra.x86_64     # additions to upstream package list
│   ├── packages.remove.x86_64    # upstream packages to drop
│   ├── airootfs-symlinks         # service enablement symlinks (created at prepare time)
│   └── upstream-units-disable    # upstream enablement symlinks to remove
├── profile-overlay/
│   ├── airootfs/                 # regular files copied into the image
│   └── templates/                # *.in files rendered with config values
├── scripts/                      # prepare, build, check, clean (+ lib/common.sh)
├── tests/                        # static checks, prepare-profile test, fixture
├── docs/                         # building, VM testing, deviations, AI design
├── work/                         # generated (ignored)
└── out/                          # generated (ignored)
```

## Documentation

- [docs/building.md](docs/building.md) - VM setup, build, troubleshooting a failed build
- [docs/vm-testing.md](docs/vm-testing.md) - booting and verifying the ISO, recovery
- [docs/upstream-deviations.md](docs/upstream-deviations.md) - every change vs. upstream and why
- [docs/ai-architecture.md](docs/ai-architecture.md) - design of the future AI controller
- [docs/next-steps.md](docs/next-steps.md) - milestone roadmap
- [specs/001-ninjas-os-foundation/](specs/001-ninjas-os-foundation/) - spec, plan, tasks
