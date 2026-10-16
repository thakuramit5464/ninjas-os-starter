# Implementation Plan: Ninjas OS Foundation

## 1. Approach
Use Archiso `releng` as the upstream baseline. A preparation script copies it to a project-owned working directory, applies custom package additions and airootfs overlays, and sets image metadata. A build script invokes `mkarchiso` and stores output in `out/`.

Do not manually reconstruct Archiso's bootloader configuration. Preserve the upstream profile and make the smallest possible changes.

## 2. Components
- `config/packages.extra.x86_64`: additional package selections.
- `profile-overlay/airootfs/`: filesystem files copied into the live image.
- `scripts/prepare-profile.sh`: creates a project-owned working profile.
- `scripts/build-iso.sh`: validates prerequisites and invokes `mkarchiso`.
- `tests/`: script validation and future policy tests.
- `out/`: generated ISO and release metadata; ignored by Git.
- `work/`: generated profile and build workspace; ignored by Git.

## 3. Build environment
- Use a supported, updated Arch Linux VM.
- Install `archiso` from official Arch repositories.
- Keep the VM snapshot before package or profile experiments.
- Use a dynamically allocated virtual disk with sufficient free space.
- Build as a normal user; invoke only the required build command through sudo.

## 4. Profile strategy
- Copy `/usr/share/archiso/configs/releng` into `work/profile`.
- Append custom packages without deleting upstream package selections.
- Copy project overlays into `work/profile/airootfs`.
- Modify only known metadata assignments in `profiledef.sh`.
- Do not mutate `/usr/share/archiso/configs/releng`.
- Check upstream profile changes when Archiso is updated.

## 5. Live desktop strategy
The first milestone includes KDE Plasma, a terminal, SDDM, Xorg/X11 session support, NetworkManager, and diagnostic tools. Desktop startup and autologin must be validated in the actual ISO. If the upstream image already enables a service or the desktop session package differs, adapt the overlay based on the installed package files rather than assuming paths.

The starter's live user is a convenience for isolated testing only. Passwordless sudo and autologin are not suitable for a production release. A later release should use a documented secure live-user strategy and separate install-time account creation.

## 6. AI architecture (later milestone)
- Python application in an unprivileged user session.
- Provider interface allowing a local model backend first.
- Structured action schema such as `open_app`, `list_allowed_directory`, and `read_system_status`.
- Independent policy engine with allowlists and argument validation.
- User confirmation UI for sensitive actions.
- Narrow executor functions, no generic `run_shell(command)` action.
- Append-only or access-controlled audit log.
- Unit tests for malformed inputs, path traversal, denied actions, and confirmation requirements.

## 7. Validation
Static checks:
- `bash -n scripts/*.sh`
- Validate expected profile paths exist before copying.
- Validate package list has no accidental blank/comment problems if useful.
- Inspect `git diff --check`.

Build checks:
- Run `scripts/build-iso.sh` on Arch VM.
- Confirm exactly where ISO output was written.
- Record `sha256sum` and package manifest.

Manual checks:
- Boot ISO in a disposable VM.
- Verify graphical session, terminal, networking, and logs.
- Revert to a VM snapshot if boot fails.

## 8. Known constraints
- Arch is rolling release; packages and upstream profile contents change.
- This plan does not guarantee bit-identical ISO output.
- Some desktop/session package names can change; verify current official repository package metadata.
- A live ISO is not an installed system image.
