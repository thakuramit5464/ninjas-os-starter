# Deviations from upstream Archiso `releng`

Ninjas OS copies `/usr/share/archiso/configs/releng` verbatim and changes it
only as listed here. Boot configuration (`syslinux/`, `efiboot/`, `grub/`,
`bootmodes`, `install_dir`, `pacman.conf`, mkinitcpio presets) is **not**
modified. Verified against archiso 91 (2026-09-29) on 2026-10-16.

| # | Change | Mechanism | Reason | Risk / notes |
| --- | --- | --- | --- | --- |
| 1 | ISO metadata: `iso_name=ninjas-os`, `iso_label=NINJAS_OS_<YYYYMM>`, `iso_version=<ver>.<YYYYMMDD>`, publisher, application | appended to `profiledef.sh` by `prepare-profile.sh` | branding, distinguishable output file names | mkarchiso substitutes label/UUID into boot entries itself, so no boot files are touched. Label stays under the 32-char ISO 9660 limit. |
| 2 | Extra `file_permissions` for `/usr/local/bin/ninjas-live-setup` (0755) and `/etc/sudoers.d/99-ninjas-live` (0440) | appended to `profiledef.sh` | git checkouts from Windows lose mode bits; sudo requires 0440 | none |
| 3 | Added packages (`config/packages.extra.x86_64`): `plasma-meta sddm konsole dolphin ark kate mesa noto-fonts ttf-dejavu pipewire pipewire-pulse wireplumber networkmanager virtualbox-guest-utils git python python-pip curl wget htop` | merged into `packages.x86_64` | KDE Plasma desktop, display manager, audio, fonts, network, VM guest tools, dev tools | ISO grows to roughly 3-4 GiB. `plasma-meta` also pulls `plasma-login-manager`; it stays installed but disabled because SDDM is the enabled display manager. |
| 4 | Removed package `virtualbox-guest-utils-nox` | `config/packages.remove.x86_64` | conflicts with `virtualbox-guest-utils`, which provides the graphical VBoxClient (resolution, clipboard) | `vboxservice.service` stays enabled upstream and works with either variant. |
| 5 | Disabled upstream enablement of `systemd-networkd.service`, `systemd-networkd.socket`, `systemd-networkd-wait-online.service`, `iwd.service`, `dbus-org.freedesktop.network1.service` | `config/upstream-units-disable` | NetworkManager manages interfaces; two network stacks fight over DHCP and Wi-Fi | packages stay installed. `systemd-resolved` stays enabled; NetworkManager uses it. Upstream `/etc/systemd/network/*.network` files remain but are inert. |
| 6 | Enabled `sddm.service` (as `display-manager.service`), `NetworkManager.service`, `ninjas-live-setup.service` | `config/airootfs-symlinks` | graphical boot and networking | Default target is already `graphical.target` via systemd's built-in default, so no `default.target` symlink is needed. |
| 7 | `ninjas-live-setup.service` + `/usr/local/bin/ninjas-live-setup`: create user `ninja` (no password; groups wheel, audio, video, storage, power, input) at boot | overlay | SDDM autologin needs a non-root user; keeping the account creation at boot avoids shipping `passwd`/`shadow`/`group` overrides that drift from the `filesystem` package | runs only when `/run/archiso` exists. `Before=display-manager.service` guarantees the user exists before SDDM reads the autologin config. |
| 8 | `/etc/sudoers.d/99-ninjas-live`: `ninja ALL=(ALL:ALL) NOPASSWD: ALL` | overlay | convenience in an isolated live session | **Not acceptable for an installed system.** Upstream already gives passwordless root on tty1 and an empty root password; this is the same trust level. |
| 9 | `/etc/sddm.conf.d/10-ninjas-live.conf`: autologin `ninja` into session `plasma`, `Relogin=false` | overlay | boot straight to the desktop | `plasma` is the Wayland session; Plasma 6.8 has no X11 session package. |
| 10 | `/etc/os-release` replaced (`NAME="Ninjas OS"`, `ID=ninjas`, `ID_LIKE=arch`, version, codename, build id) | rendered template | visible identity in KDE Info Center, `hostnamectl`, `neofetch` | tools that test `ID=arch` strictly will not recognise the system. None are known in the live image; `ID_LIKE=arch` covers the common case. Revisit if `archinstall` or pacman hooks misbehave. |
| 11 | `/etc/hostname` = `ninjas-os`, `/etc/issue`, `/etc/motd` replaced; `/etc/ninjas-os-release` added; `/etc/skel/README-NINJAS-OS.txt` added | overlay / templates | branding, diagnostics | `/etc/motd` replaces upstream's installation hints. |

Things intentionally **kept** from upstream that a reviewer should know about:

- root autologin on tty1 (`getty@tty1.service.d/autologin.conf`); SDDM takes
  tty1 (`Conflicts=getty@tty1.service`) so this only matters if SDDM fails.
- `sshd.service` enabled; root has an empty password so remote login is
  refused until a password is set, matching upstream behaviour.
- `reflector`, `choose-mirror`, `pacman-init`, `cloud-init`, Hyper-V and
  VMware guest services.
- `/root/.zlogin` launching the upstream installation guide hint on root
  console login.

How to review the effective result before building:

```bash
scripts/prepare-profile.sh
diff -ru /usr/share/archiso/configs/releng work/profile | less
```
