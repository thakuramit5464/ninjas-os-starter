# Implementation Plan: Ninjas OS Foundation

**Status:** Phase 0-1 implemented (2026-10-16); Phase 2 configured, build and VM test pending.

## 1. Approach
Use Archiso `releng` as the upstream baseline. `scripts/prepare-profile.sh` copies it to `work/profile`, applies package additions/removals and airootfs overlays, renders metadata templates, creates service-enablement symlinks, and appends image metadata overrides to `profiledef.sh`. `scripts/build-iso.sh` invokes `mkarchiso` and stores the ISO plus checksum, package manifest and build info in `out/`.

Do not manually reconstruct Archiso's bootloader configuration. Preserve the upstream profile and make the smallest possible changes, each listed in `docs/upstream-deviations.md`.

## 2. Components
- `config/ninjas-os.conf`: name, version, codename, ISO metadata, live user. Plain `KEY="value"` only; the loader rejects anything else so sourcing it cannot execute code.
- `config/packages.extra.x86_64` / `config/packages.remove.x86_64`: package deltas against upstream.
- `config/airootfs-symlinks`: symlinks created at prepare time (service enablement). Symlinks are not committed because Windows checkouts flatten them to text files (the original starter commit shipped four such broken files).
- `config/upstream-units-disable`: upstream enablement symlinks to remove (systemd-networkd, iwd).
- `profile-overlay/airootfs/`: regular files copied into the live image.
- `profile-overlay/templates/*.in`: rendered with `@NINJAS_*@` placeholders (os-release, issue, motd, ninjas-os-release).
- `scripts/lib/common.sh`: strict mode, logging, config loader, guarded recursive delete (`work/` and `out/` only).
- `scripts/prepare-profile.sh`, `scripts/build-iso.sh`, `scripts/check-prereqs.sh`, `scripts/clean.sh`.
- `tests/`: `run-static-checks.sh` (bash -n, shellcheck, CRLF, overlay/config lint), `test-prepare-profile.sh` (functional test against `tests/fixtures/fake-releng`), `run-all.sh`.
- `out/`, `work/`: generated; ignored by Git.

## 3. Build environment
- Updated Arch Linux VM; `archiso`, `git`, `shellcheck` installed.
- Snapshot the VM before package or profile experiments.
- Clone onto the VM's own Linux filesystem (not a shared folder: symlinks and modes are needed).
- Build as a normal user; `sudo` is used only for `mkarchiso` and for removing the root-owned `work/build`.

## 4. Profile strategy
- Copy `/usr/share/archiso/configs/releng` into `work/profile`; fingerprint upstream before and after and abort if it changed.
- Package list: keep upstream lines verbatim, comment out removals, append additions not already present; reject duplicates and invalid names.
- Remove the listed upstream enablement symlinks; warn (not fail) when one is absent so upstream changes surface.
- Copy overlay (regular files only; a symlink in the overlay is a hard error), render templates, create declared symlinks.
- Append overrides to `profiledef.sh` (values escaped with `printf %q`): `iso_name`, `iso_label` (`NINJAS_OS_<YYYYMM>`), `iso_version` (`<version>.<YYYYMMDD>`), publisher, application, `file_permissions+=` for the live-setup script and sudoers file. Warn if upstream stops defining a field.
- Verify by sourcing the resulting `profiledef.sh` the way mkarchiso does.
- Record `SOURCE_DATE_EPOCH` in the profile so build and templates share one timestamp.
- Upstream facts verified 2026-10-16 (archiso 91): `bootmodes=('bios.syslinux' 'uefi.systemd-boot')`, `install_dir="arch"`, multi-arch profile (`packages.aarch64` present); boot entries use `%ARCHISO_UUID%`/`%ARCHISO_LABEL%` substitution so changing the label is safe.

## 5. Live desktop strategy
- Plasma 6.8 (`plasma-meta`) on **Wayland**; Arch no longer ships `plasma-x11-session` and `plasma-workspace` conflicts with it.
- SDDM as display manager (enabled via `display-manager.service` symlink). `plasma-meta` also installs `plasma-login-manager`; it is left disabled. Revisit when choosing a final login manager.
- NetworkManager replaces systemd-networkd/iwd enablement; systemd-resolved stays.
- `virtualbox-guest-utils` replaces upstream `-nox` variant (they conflict).
- Live user `ninja` created at boot by `ninjas-live-setup.service` (`ConditionPathIsDirectory=/run/archiso`, `Before=display-manager.service`); autologin and passwordless sudo shipped as static overlay files. This is a live-image convenience only; an installer must create real accounts.
- Desktop startup must be validated in the actual ISO (UEFI and BIOS). If the session fails, adapt based on `/usr/share/wayland-sessions` and SDDM logs rather than assumptions.

## 6. AI architecture (later milestone)
See `docs/ai-architecture.md`. Summary: Python, unprivileged `systemd --user` service, local provider first, typed pydantic action schema with `extra="forbid"`, independent deny-by-default policy engine with risk classes, confirmation UI the model cannot drive, narrow executors using argv lists with timeouts, redacted append-only audit log, tests for traversal/injection/confirmation before any real execution.

## 7. Validation
Static (any host, no root): `tests/run-all.sh` → `bash -n`, shellcheck (when installed), CRLF, overlay and config lint, fixture-based prepare test (upstream untouched, packages merged, symlinks, templates, profiledef overrides, idempotency, failure modes).

Build (Arch VM): `scripts/check-prereqs.sh --packages`, `scripts/build-iso.sh`; inspect `work/logs/*.log`; keep `out/*.sha256`, `*.pkglist.txt`, `*.build-info.txt`.

Manual (disposable VM): `docs/vm-testing.md` checklist, UEFI and BIOS; revert to snapshot between ISOs.

## 8. Known constraints
- Arch is rolling release; package names and the upstream profile change. `check-prereqs.sh --packages` and the fixture diff catch this early.
- No bit-identical output; `SOURCE_DATE_EPOCH` is recorded, but package contents follow the mirror unless an Arch Linux Archive snapshot is pinned in `pacman.conf`.
- Windows hosts cannot run the functional test's symlink assertions nor the build; those run in the Arch VM.
- A live ISO is not an installed system image.
