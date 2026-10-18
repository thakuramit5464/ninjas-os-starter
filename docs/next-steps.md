# Next steps

Status as of 2026-10-16: Phase 0 (hygiene) and Phase 1 (profile preparation)
are implemented and unit-tested on a Windows host. Phase 2 configuration is
written but **the ISO has not been built**, and Phase 3 (VM smoke test) has not
started. See `specs/001-ninjas-os-foundation/tasks.md` for the checklist.

## Immediately (inside the Arch VM)

1. `sudo pacman -Syu && sudo pacman -S --needed archiso git shellcheck`
2. `tests/run-all.sh` - must pass including the symlink assertions that are
   skipped on Windows.
3. `scripts/check-prereqs.sh --packages` - confirms every package name still
   exists.
4. `scripts/build-iso.sh` - first real build. Keep `work/logs/*.log`.
5. Boot `out/ninjas-os-*.iso` in a disposable VM following
   `docs/vm-testing.md`; test UEFI and BIOS.
6. Record results (checksum, archiso version, what passed) in `tasks.md` and
   the README's verification table. Fix what failed in `config/` or
   `profile-overlay/`, never by hand inside the VM.

## Then

- Decide whether `plasma-meta` is the right scope (it pulls `plasma-login-manager`,
  Discover, Flatpak KCM, KRDP, ...) or whether a curated Plasma set is leaner
  and still complete. Measure ISO size and boot time first.
- Branding: wallpaper, SDDM theme, Plasma look-and-feel, logo for
  `/etc/os-release` `LOGO=`.
- Optional: pin an Arch Linux Archive snapshot in `pacman.conf` for repeatable
  package sets; document the chosen date in `build-info`.
- CI: run `tests/run-all.sh` in an Arch container on every push; a full
  `mkarchiso` build needs a privileged runner and is a later addition.

## Later (only after the ISO boots reliably)

- AI controller per `docs/ai-architecture.md`: schema, policy engine, audit
  log and tests first; executor functions second; perception last.
- Installer story (Calamares or archinstall profile) with a proper
  install-time account instead of the live `ninja` user.
