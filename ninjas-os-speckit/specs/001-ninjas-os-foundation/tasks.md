# Tasks: Ninjas OS Foundation

## Phase 0 — Repository hygiene
- [ ] T001 Add README, project layout, and build prerequisites.
- [ ] T002 Add `.gitignore` for generated profile, work directory, ISO, and logs.
- [ ] T003 Add constitution and feature spec.
- [ ] T004 Add a shell syntax-check command or lightweight test script.

## Phase 1 — Archiso profile
- [ ] T010 Check Archiso installation and presence of `/usr/share/archiso/configs/releng`.
- [ ] T011 Implement safe profile copy into `work/profile`.
- [ ] T012 Append custom package list to the copied profile only.
- [ ] T013 Overlay project-owned `airootfs` files.
- [ ] T014 Set ISO name, label, publisher, and application metadata if the upstream profile exposes those fields.
- [ ] T015 Ensure script never modifies the installed upstream profile.

## Phase 2 — Live desktop
- [ ] T020 Select and validate package names for KDE, terminal, display manager, and network manager.
- [ ] T021 Configure graphical boot using the current Archiso profile conventions.
- [ ] T022 Add Ninjas OS welcome/issue branding.
- [ ] T023 Decide live-user strategy; document autologin and sudo implications.
- [ ] T024 Build ISO and inspect build logs.

## Phase 3 — VM smoke test
- [ ] T030 Boot ISO in a disposable UEFI VM.
- [ ] T031 Verify KDE session and terminal.
- [ ] T032 Verify NetworkManager and connectivity.
- [ ] T033 Verify live setup service and welcome marker.
- [ ] T034 Document failures, fixes, and recovery commands.
- [ ] T035 Generate SHA-256 checksum and package manifest.

## Phase 4 — AI controller design
- [ ] T040 Define a typed action schema; do not accept arbitrary shell strings.
- [ ] T041 Implement policy validator and deny-by-default behavior.
- [ ] T042 Implement narrow unprivileged executor functions.
- [ ] T043 Add confirmation handling for sensitive operations.
- [ ] T044 Add audit logging that avoids secrets and sensitive content.
- [ ] T045 Add tests for malformed actions, denied actions, and path traversal.

## Phase 5 — Branding and release
- [ ] T050 Add logo, wallpaper, desktop theme, and login-screen branding.
- [ ] T051 Add release version metadata.
- [ ] T052 Document USB creation with a separate removable device and explicit target verification.
- [ ] T053 Add a release checklist and known limitations.
