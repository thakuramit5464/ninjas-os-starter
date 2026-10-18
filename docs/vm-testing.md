# Testing the ISO in a disposable VM

Never test a new ISO on real hardware first. Use a VM you can throw away, and
snapshot it before every new image.

## Test VM settings (VirtualBox)

| Setting | Value | Why |
| --- | --- | --- |
| Type | Linux / Arch Linux (64-bit) | |
| CPUs | 2-4 | |
| RAM | 4 GiB minimum, 6 GiB recommended | live image runs from RAM + squashfs |
| System > Enable EFI | **on** for one run, **off** for another | tests both systemd-boot (UEFI) and syslinux (BIOS) paths |
| Display > Graphics controller | VMSVGA, 128 MiB video memory | Plasma Wayland uses the `vmwgfx` kernel driver with software rendering |
| Display > 3D acceleration | off first; try on later | avoids GPU driver surprises during first boot |
| Storage | attach `out/ninjas-os-*.iso` to the optical drive | |
| Network | NAT | NetworkManager should get DHCP |

QEMU alternative:

```bash
qemu-system-x86_64 -enable-kvm -m 6G -smp 4 -cdrom out/ninjas-os-*.iso \
  -device virtio-vga -display gtk -nic user
# UEFI: add  -bios /usr/share/edk2/x64/OVMF.4m.fd  (package: edk2-ovmf)
```

## Boot checklist

Record the actual result of each line; do not tick what you did not see.

1. Boot menu appears with the Archiso entry and boots the kernel.
2. Console shows the Ninjas OS `/etc/issue` banner briefly (tty switch with
   Ctrl+Alt+F2 to read it; log in as `root` with no password).
3. SDDM starts and auto-logs `ninja` into Plasma (Wayland). A
   `Welcome-to-Ninjas-OS.txt` file is on the desktop.
4. Konsole opens; `cat /etc/os-release` shows `NAME="Ninjas OS"`.
5. `systemctl status ninjas-live-setup` is `active (exited)` with "done" in
   its log.
6. `systemctl --failed` lists nothing unexpected (VM guest services for other
   hypervisors may be inactive; that is fine).
7. `nmcli device status` shows the NIC `connected`; `curl -I https://archlinux.org`
   returns HTTP 200/3xx.
8. Audio device visible in the Plasma volume applet (optional).
9. `sudo true` works without a password.
10. Shutdown from the Plasma menu completes.

Repeat 1 with EFI toggled the other way.

## When it fails

Switch to a text console: Ctrl+Alt+F2 (or F3), log in as `root` (no
password).

```bash
journalctl -b -p err              # errors this boot
systemctl --failed
systemctl status sddm ninjas-live-setup NetworkManager
journalctl -b -u sddm -u ninjas-live-setup
cat /etc/sddm.conf.d/10-ninjas-live.conf
ls /usr/share/wayland-sessions/   # should list plasma.desktop
id ninja                          # user exists?
```

Common outcomes:

| Observation | Meaning | Where to fix |
| --- | --- | --- |
| black screen, SDDM not running | SDDM failed to start a greeter (GPU/VT issue) | try VMSVGA without 3D, or `systemctl restart sddm`; check `journalctl -u sddm` |
| SDDM greeter visible, no autologin | user missing or session name wrong | `id ninja`; compare `Session=` with `/usr/share/wayland-sessions/*.desktop` |
| `ninjas-live-setup` failed | useradd/group problem | read its journal; the script logs each step |
| no network | NetworkManager not enabled or networkd still running | `systemctl status NetworkManager systemd-networkd`; check `config/airootfs-symlinks` and `config/upstream-units-disable` |
| `pacstrap`/package errors at build | rolling release changed names | see [building.md](building.md) |

You can edit files in the live session to test a fix, but the fix must then be
applied to the repository (`profile-overlay/`, `config/`) and rebuilt; live
changes are lost on reboot.

## Recovery

- Revert the test VM to its snapshot before trying the next ISO.
- Rebuild with `scripts/build-iso.sh`; the previous ISO in `out/` is
  overwritten only if it has the same version and date.
- `scripts/clean.sh` resets `work/` if the prepared profile is suspect.

## Recording results

After a successful boot test, record in the pull request or commit message:

- the ISO file name and its `.sha256`,
- `archiso_version` and `git_revision` from `out/<iso>.build-info.txt`,
- which boot mode(s) were tested (UEFI, BIOS),
- the hypervisor and its version,
- which checklist items passed and which did not.

Update `specs/001-ninjas-os-foundation/tasks.md` (Phase 3) accordingly.

## USB (later)

Writing to a USB device is **manual and never done by the scripts**. When you
get there:

1. Use a dedicated, empty USB stick. Everything on it will be erased.
2. Identify the device with `lsblk -o NAME,SIZE,MODEL,TRAN` **before and after**
   plugging it in; confirm `TRAN=usb` and the size matches.
3. Make sure it is not mounted (`findmnt /dev/sdX*`).
4. Only then: `sudo dd if=out/ninjas-os-*.iso of=/dev/sdX bs=4M status=progress oflag=sync`
   (use the whole device, not a partition).
5. Boot a spare machine from it. Never the Windows host's internal disk.
