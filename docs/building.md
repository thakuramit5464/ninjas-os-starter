# Building the Ninjas OS ISO

The build must run on **Arch Linux** because `mkarchiso` uses `pacstrap`,
`mksquashfs`, `xorriso`, and the host's pacman configuration. On a Windows
host, use an Arch Linux virtual machine.

## 1. Build VM

Any hypervisor works. Suggested VirtualBox settings:

| Setting | Value |
| --- | --- |
| Type | Linux / Arch Linux (64-bit) |
| CPUs | 4 |
| RAM | 6-8 GiB (squashfs xz compression is memory hungry) |
| Disk | 60-80 GiB dynamically allocated |
| EFI | optional for the build VM, **required** for the test VM to check UEFI boot |
| Network | NAT |

Install Arch normally (or with `archinstall`), create a non-root user in the
`wheel` group with sudo, then:

```bash
sudo pacman -Syu
sudo pacman -S --needed archiso git shellcheck
```

Take a VM snapshot ("clean build host") before the first build.

## 2. Get the sources

```bash
git clone https://github.com/thakuramit5464/ninjas-os-starter.git ninjas-os
cd ninjas-os
```

If you copy the tree from Windows through a shared folder instead, make sure
the files kept LF line endings and executable bits:

```bash
tests/run-static-checks.sh        # fails on CRLF
chmod +x scripts/*.sh tests/*.sh profile-overlay/airootfs/usr/local/bin/*
```

Do **not** build from a VirtualBox shared folder or a FAT/NTFS mount: symlinks
and Unix permissions are required. Clone into the VM's own ext4/btrfs disk.

## 3. Validate

```bash
tests/run-all.sh                     # no root, no network
scripts/check-prereqs.sh --packages  # needs synced pacman db: sudo pacman -Sy first
```

`check-prereqs.sh --packages` runs `pacman -Si` for every entry of
`config/packages.extra.x86_64`. A missing package means Arch renamed or
dropped it; fix the config before building.

## 4. Build

```bash
scripts/build-iso.sh
```

What happens:

1. `check-prereqs.sh --packages` (skip with `--skip-package-check`).
2. `prepare-profile.sh` recreates `work/profile` from upstream + this repo.
3. `work/build` from a previous run is removed with `sudo rm -rf` (restricted
   to that path; keep it with `--keep-build-dir`).
4. `sudo env SOURCE_DATE_EPOCH=<epoch> mkarchiso -v -w work/build -o out work/profile`
   with the full log tee'd to `work/logs/mkarchiso-<timestamp>.log`.
5. `out/<iso>.sha256`, `out/<iso>.pkglist.txt` (every package and version in
   the image) and `out/<iso>.build-info.txt` are written and the ISO is
   chowned to your user.

Expect 15-40 minutes and several GiB of downloads on the first run. Pacman's
package cache (`/var/cache/pacman/pkg`) is reused by later builds.

`scripts/build-iso.sh --dry-run` prints the plan and the exact `mkarchiso`
command without executing anything.

### Reproducibility

Set `SOURCE_DATE_EPOCH` to pin the timestamp used for the ISO label, version
and metadata:

```bash
SOURCE_DATE_EPOCH=1760572800 scripts/build-iso.sh
```

Package contents still come from whatever mirror state the VM has. For a
repeatable package set, point `work/profile/pacman.conf` at an Arch Linux
Archive snapshot (`https://archive.archlinux.org/repos/YYYY/MM/DD/$repo/os/$arch`)
before building. This is deliberately not automated yet.

## 5. Troubleshooting a failed build

Always read `work/logs/mkarchiso-*.log` first.

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `target not found: <pkg>` | package renamed/removed (rolling release) | `scripts/check-prereqs.sh --packages`; edit `config/packages.extra.x86_64` |
| `unresolvable package conflicts` | a new upstream package conflicts with ours | add the upstream package to `config/packages.remove.x86_64` and document it |
| `failed retrieving file` / signature errors | stale mirrors or keyring | `sudo pacman -Syu archlinux-keyring`; pick fresh mirrors |
| `No space left on device` | `work/` filesystem too small | free space or move the clone; `scripts/clean.sh` |
| `profiledef.sh already contains overrides` | stale `work/profile` | `scripts/clean.sh` then rebuild |
| `upstream profiledef.sh does not define <field>` warning | Archiso changed its profile format | compare `/usr/share/archiso/configs/releng/profiledef.sh` with `tests/fixtures/fake-releng/profiledef.sh`, update scripts + fixture |
| ISO built but desktop fails | see [vm-testing.md](vm-testing.md) | |

Upstream profile changes: after every `pacman -Syu` that updates `archiso`,
diff the installed profile against the fixture:

```bash
diff /usr/share/archiso/configs/releng/profiledef.sh tests/fixtures/fake-releng/profiledef.sh
ls /usr/share/archiso/configs/releng/airootfs/etc/systemd/system/multi-user.target.wants/
```

`prepare-profile.sh` warns (does not fail) when an entry of
`config/upstream-units-disable` or `config/packages.remove.x86_64` is no
longer present upstream.

## 6. Cleaning up

```bash
scripts/clean.sh            # remove work/ (uses sudo for root-owned build files)
scripts/clean.sh --out      # also remove out/
```

Deletion is constrained to `work/` and `out/` inside the repository; any other
path is refused.
