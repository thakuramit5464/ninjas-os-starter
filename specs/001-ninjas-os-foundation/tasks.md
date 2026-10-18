# Tasks: Ninjas OS Foundation

Legend: `[x]` done and verified by the stated check · `[~]` implemented, verification pending · `[ ]` open.
Last update: 2026-10-16 (Windows host; Arch VM steps not yet run).

## Phase 0 — Repository hygiene
- [x] T001 Add README, project layout, and build prerequisites. *(README.md, docs/building.md)*
- [x] T002 Add `.gitignore` for generated profile, work directory, ISO, and logs. *(+ `.gitattributes` LF normalisation, `.editorconfig`)*
- [x] T003 Add constitution and feature spec. *(moved from `ninjas-os-speckit/` to the repo root as the pack's README instructs)*
- [x] T004 Add a shell syntax-check command or lightweight test script. *(`tests/run-static-checks.sh`, `tests/run-all.sh`; passed locally)*

## Phase 1 — Archiso profile
- [x] T010 Check Archiso installation and presence of `/usr/share/archiso/configs/releng`. *(`scripts/check-prereqs.sh`; fails with install hint)*
- [x] T011 Implement safe profile copy into `work/profile`. *(`prepare-profile.sh`; `ninjas_safe_rm_rf` restricted to work/out; tested)*
- [x] T012 Append custom package list to the copied profile only. *(merge with removals + dedupe; tested against fixture)*
- [x] T013 Overlay project-owned `airootfs` files. *(regular files via overlay, symlinks via `config/airootfs-symlinks`; tested)*
- [x] T014 Set ISO name, label, publisher, and application metadata if the upstream profile exposes those fields. *(appended overrides; verified by sourcing profiledef in test)*
- [x] T015 Ensure script never modifies the installed upstream profile. *(SHA-256 fingerprint before/after inside the script; tested)*
- [~] T016 Run `tests/run-all.sh` inside the Arch VM so the symlink assertions execute. *(skipped on Windows: host cannot create symlinks)*

## Phase 2 — Live desktop
- [~] T020 Select and validate package names for KDE, terminal, display manager, and network manager. *(names verified on archlinux.org 2026-10-16: plasma-meta 6.8, sddm 0.21, networkmanager 1.58, virtualbox-guest-utils 7.2; `plasma-x11-session` removed because it no longer exists. Must re-run `check-prereqs.sh --packages` in the VM.)*
- [~] T021 Configure graphical boot using the current Archiso profile conventions. *(SDDM enabled via display-manager.service symlink; networkd/iwd enablement removed; NetworkManager enabled. Unverified until boot test.)*
- [x] T022 Add Ninjas OS welcome/issue branding. *(os-release, issue, motd, hostname, ninjas-os-release, skel README, desktop marker)*
- [x] T023 Decide live-user strategy; document autologin and sudo implications. *(`docs/upstream-deviations.md` rows 7-9)*
- [ ] T024 Build ISO and inspect build logs. *(`scripts/build-iso.sh` in the Arch VM)*

## Phase 3 — VM smoke test
- [ ] T030 Boot ISO in a disposable UEFI VM (and once in BIOS mode).
- [ ] T031 Verify KDE session and terminal.
- [ ] T032 Verify NetworkManager and connectivity.
- [ ] T033 Verify live setup service and welcome marker.
- [ ] T034 Document failures, fixes, and recovery commands. *(template: docs/vm-testing.md)*
- [~] T035 Generate SHA-256 checksum and package manifest. *(automated in `build-iso.sh`; produces `.sha256`, `.pkglist.txt`, `.build-info.txt`; not yet exercised)*

## Phase 4 — AI controller design
- [~] T040 Define a typed action schema; do not accept arbitrary shell strings. *(design in docs/ai-architecture.md; no code)*
- [ ] T041 Implement policy validator and deny-by-default behavior.
- [ ] T042 Implement narrow unprivileged executor functions.
- [ ] T043 Add confirmation handling for sensitive operations.
- [ ] T044 Add audit logging that avoids secrets and sensitive content.
- [ ] T045 Add tests for malformed actions, denied actions, and path traversal.

## Phase 5 — Branding and release
- [ ] T050 Add logo, wallpaper, desktop theme, and login-screen branding.
- [x] T051 Add release version metadata. *(`config/ninjas-os.conf`, `/etc/ninjas-os-release`, build-info)*
- [x] T052 Document USB creation with a separate removable device and explicit target verification. *(docs/vm-testing.md "USB (later)")*
- [~] T053 Add a release checklist and known limitations. *(README verification table + rolling-release caveat; release checklist in spec §10 still open)*
