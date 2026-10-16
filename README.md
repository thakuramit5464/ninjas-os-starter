# Ninjas OS — Alpha 0.1 starter

A fully scripted Arch-based live ISO starter, built with Archiso from an Arch Linux VM.

## What this starter does

- Uses the installed Archiso `releng` profile as the upstream baseline.
- Adds a small Ninjas OS package list and filesystem overlay.
- Adds a live-session first-boot helper to create a non-root `ninja` user.
- Adds basic branding and a README marker.
- Builds a bootable ISO with `mkarchiso`.

This is a development starter, not a production distribution. It does not yet include the AI agent.

## Build host

Run the build inside an up-to-date Arch Linux VM. Do not run the ISO-writing commands against your Windows/internal disk.

## Quick start

```bash
sudo pacman -Syu
sudo pacman -S --needed archiso git
git clone <YOUR-REPOSITORY-URL> ninjas-os
cd ninjas-os
./scripts/build-iso.sh
```

If the project is already copied into the VM, skip `git clone` and `cd` into its directory.

The first build script copies `/usr/share/archiso/configs/releng` into `work/profile` and overlays the Ninjas OS files there. Generated profile files and build outputs are kept out of the source profile.

Output: `out/ninjas-os-<version>-x86_64.iso`

## Test

1. In VirtualBox, create a new Linux (64-bit) VM with 4 vCPUs, 6–8 GB RAM, and a 60–80 GB dynamically allocated virtual disk.
2. Attach the generated ISO to the VM's virtual optical drive.
3. Boot it and choose the Archiso live boot entry.
4. The first-boot service attempts to create a live user named `ninja` and configure SDDM autologin.
5. Verify KDE, networking, and the desktop marker file.

Because Arch packages are rolling-release, package availability and desktop boot behavior can change. If the desktop fails, boot the live environment's console, inspect `journalctl -b`, and check `systemctl status sddm`.

## Security notes

- This is a live-development image. The live `ninja` account is configured for passwordless sudo for convenience. Do not use this profile as a secure installed OS or expose it to untrusted networks.
- Do not give the future AI agent unrestricted root or shell access.
- Use a VM snapshot before testing each new ISO.
- Always verify the target device before writing an ISO to a USB drive; writing an image erases the selected device.

## Project layout

```text
ninjas-os/
├── README.md
├── .gitignore
├── config/
│   └── packages.extra.x86_64
├── profile-overlay/
│   └── airootfs/
│       ├── etc/
│       │   ├── issue
│       │   ├── skel/
│       │   └── systemd/system/
│       └── usr/local/bin/
├── scripts/
│   ├── build-iso.sh
│   └── prepare-profile.sh
└── work/                 # generated; ignored by Git
```
