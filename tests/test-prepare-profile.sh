#!/usr/bin/env bash
# Functional test for scripts/prepare-profile.sh using the fake upstream
# profile in tests/fixtures/fake-releng. Runs without root or Archiso.
#
# It verifies that preparation:
#   - leaves the upstream profile byte-for-byte unchanged,
#   - produces work/profile with merged packages (removals commented out,
#     additions appended once, no duplicates),
#   - removes the upstream networkd/iwd enablement and creates the declared
#     symlinks (skipped where the filesystem cannot create symlinks),
#   - applies the overlay and renders templates with the configured metadata,
#   - appends profiledef.sh overrides that source correctly,
#   - is idempotent (second run gives identical results),
#   - refuses to run as root and refuses a missing upstream profile.
#
# Usage: tests/test-prepare-profile.sh [--keep]

set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
keep=0
[[ "${1:-}" == "--keep" ]] && keep=1

pass=0 fail=0 skip=0
ok()   { printf '  PASS  %s\n' "$*"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$*" >&2; fail=$((fail + 1)); }
skip() { printf '  SKIP  %s\n' "$*"; skip=$((skip + 1)); }
assert_file()    { if [[ -f "$1" ]]; then ok "file exists: ${1#"${TMP}"/}"; else bad "missing file: ${1#"${TMP}"/}"; fi; }
assert_absent()  { if [[ ! -e "$1" && ! -L "$1" ]]; then ok "absent: ${1#"${TMP}"/}"; else bad "should be absent: ${1#"${TMP}"/}"; fi; }
assert_grep()    { if grep -Eq -- "$1" "$2"; then ok "'$1' in ${2#"${TMP}"/}"; else bad "'$1' not found in ${2#"${TMP}"/}"; fi; }
assert_no_grep() { if ! grep -Eq -- "$1" "$2"; then ok "'$1' absent from ${2#"${TMP}"/}"; else bad "'$1' unexpectedly present in ${2#"${TMP}"/}"; fi; }

TMP="$(mktemp -d "${ROOT_DIR}/tests/.tmp/prepare.XXXXXX" 2>/dev/null || { mkdir -p "${ROOT_DIR}/tests/.tmp" && mktemp -d "${ROOT_DIR}/tests/.tmp/prepare.XXXXXX"; })"
cleanup() { (( keep )) || rm -rf -- "${TMP}"; }
trap cleanup EXIT

export NINJAS_UPSTREAM_PROFILE="${TMP}/upstream"
export NINJAS_WORK_DIR="${TMP}/work"
export NINJAS_OUT_DIR="${TMP}/out"
export SOURCE_DATE_EPOCH=1760572800   # 2025-10-16T00:00:00Z, fixed for determinism
export NO_COLOR=1

cp -a -- "${ROOT_DIR}/tests/fixtures/fake-releng" "${NINJAS_UPSTREAM_PROFILE}"

# Recreate the upstream enablement symlinks the fixture cannot store.
can_symlink=1
units="${NINJAS_UPSTREAM_PROFILE}/airootfs/etc/systemd/system"
mkdir -p "${units}/multi-user.target.wants" "${units}/network-online.target.wants" "${units}/sockets.target.wants"
ln -sfn /usr/lib/systemd/system/iwd.service "${units}/multi-user.target.wants/iwd.service" 2>/dev/null || true
if [[ ! -L "${units}/multi-user.target.wants/iwd.service" ]]; then
  can_symlink=0
  rm -f "${units}/multi-user.target.wants/iwd.service"
else
  ln -sfn /usr/lib/systemd/system/systemd-networkd.service "${units}/multi-user.target.wants/systemd-networkd.service"
  ln -sfn /usr/lib/systemd/system/systemd-resolved.service "${units}/multi-user.target.wants/systemd-resolved.service"
  ln -sfn /usr/lib/systemd/system/sshd.service "${units}/multi-user.target.wants/sshd.service"
  ln -sfn /usr/lib/systemd/system/systemd-networkd-wait-online.service "${units}/network-online.target.wants/systemd-networkd-wait-online.service"
  ln -sfn /usr/lib/systemd/system/systemd-networkd.socket "${units}/sockets.target.wants/systemd-networkd.socket"
  ln -sfn /usr/lib/systemd/system/systemd-networkd.service "${units}/dbus-org.freedesktop.network1.service"
fi

fingerprint() {
  (
    cd -- "$1" || exit 1
    find . -print0 | sort -z | while IFS= read -r -d '' e; do
      if [[ -L "${e}" ]]; then printf 'L %s -> %s
' "${e}" "$(readlink -- "${e}")"
      elif [[ -d "${e}" ]]; then printf 'D %s
' "${e}"
      else printf 'F %s %s
' "${e}" "$(sha256sum -- "${e}" | cut -d' ' -f1)"; fi
    done
  ) | sha256sum
}
before="$(fingerprint "${NINJAS_UPSTREAM_PROFILE}")"
if (( ! can_symlink )); then
  export NINJAS_SKIP_SYMLINKS=1
  skip "this filesystem cannot create symlinks; running prepare-profile.sh with NINJAS_SKIP_SYMLINKS=1 (symlink assertions skipped; run this test in the Arch VM for full coverage)"
fi

printf '== run prepare-profile.sh (fixture upstream)\n'
if out="$("${ROOT_DIR}/scripts/prepare-profile.sh" 2>&1)"; then
  ok "prepare-profile.sh exited 0"
else
  bad "prepare-profile.sh failed:"$'\n'"${out}"
  printf '%s\n' "${out}"
  exit 1
fi

profile="${NINJAS_WORK_DIR}/profile"
airootfs="${profile}/airootfs"

printf '== upstream untouched\n'
after="$(fingerprint "${NINJAS_UPSTREAM_PROFILE}")"
if [[ "${before}" == "${after}" ]]; then ok "upstream fingerprint unchanged"; else bad "upstream profile was modified"; fi

printf '== package list\n'
pkgs="${profile}/packages.x86_64"
assert_file "${pkgs}"
assert_grep '^# removed by Ninjas OS .*: virtualbox-guest-utils-nox$' "${pkgs}"
assert_no_grep '^virtualbox-guest-utils-nox$' "${pkgs}"
assert_grep '^virtualbox-guest-utils$' "${pkgs}"
assert_grep '^plasma-meta$' "${pkgs}"
assert_grep '^networkmanager$' "${pkgs}"
assert_grep '^base$' "${pkgs}"
assert_grep '^iwd$' "${pkgs}"   # package stays, only enablement is removed
effective="$(sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "${pkgs}")"
if [[ "$(grep -cx 'nano' <<<"${effective}")" -eq 1 ]]; then ok "upstream duplicate 'nano' not re-added"; else bad "'nano' appears $(grep -cx nano <<<"${effective}") times"; fi
if [[ "$(grep -cx 'sudo' <<<"${effective}")" -eq 1 ]]; then ok "'sudo' appears exactly once"; else bad "'sudo' duplicated"; fi
if [[ -z "$(sort <<<"${effective}" | uniq -d)" ]]; then ok "no duplicate packages"; else bad "duplicates: $(sort <<<"${effective}" | uniq -d | tr '\n' ' ')"; fi
if [[ -z "$(grep -Ev '^[a-z0-9@._+-]+$' <<<"${effective}")" ]]; then ok "all effective entries are valid package names"; else bad "invalid entries in merged list"; fi

printf '== upstream enablement removed, declared symlinks created\n'
sys="${airootfs}/etc/systemd/system"
if (( can_symlink )); then
  assert_absent "${sys}/multi-user.target.wants/iwd.service"
  assert_absent "${sys}/multi-user.target.wants/systemd-networkd.service"
  assert_absent "${sys}/network-online.target.wants/systemd-networkd-wait-online.service"
  assert_absent "${sys}/sockets.target.wants/systemd-networkd.socket"
  assert_absent "${sys}/dbus-org.freedesktop.network1.service"
  if [[ -L "${sys}/multi-user.target.wants/systemd-resolved.service" ]]; then ok "systemd-resolved enablement kept"; else bad "systemd-resolved enablement lost"; fi
  if [[ -L "${sys}/multi-user.target.wants/sshd.service" ]]; then ok "unrelated upstream enablement kept (sshd)"; else bad "sshd enablement lost"; fi
  check_link() {
    local link="$1" want="$2" got
    if [[ -L "${sys}/${link}" ]]; then
      got="$(readlink -- "${sys}/${link}")"
      if [[ "${got}" == "${want}" ]]; then ok "symlink ${link} -> ${want}"; else bad "symlink ${link} -> ${got} (want ${want})"; fi
    else
      bad "symlink missing: ${link}"
    fi
  }
  check_link display-manager.service /usr/lib/systemd/system/sddm.service
  check_link multi-user.target.wants/NetworkManager.service /usr/lib/systemd/system/NetworkManager.service
  check_link dbus-org.freedesktop.NetworkManager.service /usr/lib/systemd/system/NetworkManager.service
  check_link multi-user.target.wants/ninjas-live-setup.service /etc/systemd/system/ninjas-live-setup.service
  # Every /etc symlink target must resolve inside the prepared airootfs.
  while IFS= read -r l; do
    t="$(readlink -- "${l}")"
    if [[ "${t}" == /etc/* && ! -f "${airootfs}${t}" ]]; then bad "dangling symlink ${l#"${airootfs}"} -> ${t}"; fi
  done < <(find "${sys}" -type l)
  ok "no dangling /etc symlink targets"
else
  skip "filesystem cannot create symlinks here; symlink assertions skipped (run in the Arch VM)"
fi

printf '== overlay and templates\n'
assert_file "${airootfs}/etc/systemd/system/ninjas-live-setup.service"
assert_file "${airootfs}/usr/local/bin/ninjas-live-setup"
assert_file "${airootfs}/etc/sudoers.d/99-ninjas-live"
assert_file "${airootfs}/etc/sddm.conf.d/10-ninjas-live.conf"
assert_file "${airootfs}/etc/skel/README-NINJAS-OS.txt"
assert_grep '^ninjas-os$' "${airootfs}/etc/hostname"
assert_file "${airootfs}/etc/os-release"
assert_grep '^NAME="Ninjas OS"$' "${airootfs}/etc/os-release"
assert_grep '^ID=ninjas$' "${airootfs}/etc/os-release"
assert_grep '^ID_LIKE=arch$' "${airootfs}/etc/os-release"
assert_grep '^VERSION_ID=0\.1\.0-alpha$' "${airootfs}/etc/os-release"
assert_grep '^BUILD_ID=2025-10-16$' "${airootfs}/etc/os-release"
assert_no_grep '@[A-Z_]+@' "${airootfs}/etc/os-release"
assert_file "${airootfs}/etc/issue"
assert_grep 'Ninjas OS 0\.1\.0-alpha' "${airootfs}/etc/issue"
assert_no_grep 'Upstream motd' "${airootfs}/etc/motd"
assert_grep 'Welcome to Ninjas OS' "${airootfs}/etc/motd"
assert_grep '^NINJAS_SOURCE_DATE_EPOCH="1760572800"$' "${airootfs}/etc/ninjas-os-release"
assert_grep '^NINJAS_LIVE_USER="ninja"$' "${airootfs}/etc/ninjas-os-release"
assert_grep '^NINJAS_GIT_REVISION="' "${airootfs}/etc/ninjas-os-release"
if [[ -f "${airootfs}/usr/local/bin/choose-mirror" ]]; then ok "upstream airootfs files preserved"; else bad "upstream airootfs file lost"; fi
if [[ -z "$(find "${profile}/templates" 2>/dev/null)" ]]; then ok "templates directory not copied into profile"; else bad "templates/ leaked into profile"; fi

printf '== profiledef.sh overrides\n'
pd="${profile}/profiledef.sh"
assert_grep '^iso_name="archlinux"' "${pd}"              # upstream kept for review
assert_grep '^iso_name=ninjas-os$' "${pd}"
assert_grep '^iso_label=NINJAS_OS_202510$' "${pd}"
assert_grep '^iso_version=0\.1\.0-alpha\.20251016$' "${pd}"
assert_grep '^iso_publisher=Ninjas\\ OS\\ Project$' "${pd}"
assert_grep '^file_permissions\+=\($' "${pd}"
if bash -n "${pd}"; then ok "profiledef.sh parses"; else bad "profiledef.sh syntax error"; fi
sourced="$(
  set -e; declare -A file_permissions
  # shellcheck disable=SC1090
  source "${pd}"
  # shellcheck disable=SC2154  # iso_* come from profiledef.sh
  printf '%s|%s|%s|%s|%s|%s' "${iso_name}" "${iso_label}" "${iso_version}" "${iso_publisher}" \
    "${file_permissions[/usr/local/bin/ninjas-live-setup]:-}" "${file_permissions[/etc/shadow]:-}"
)"
if [[ "${sourced}" == "ninjas-os|NINJAS_OS_202510|0.1.0-alpha.20251016|Ninjas OS Project|0:0:755|0:0:400" ]]; then
  ok "sourced profiledef.sh yields the Ninjas OS metadata and merged file_permissions"
else
  bad "sourced profiledef.sh gave: ${sourced}"
fi
assert_grep "^install_dir=\"arch\"" "${pd}"
assert_grep "^bootmodes=\('bios.syslinux'" "${pd}"    # upstream boot config untouched
if [[ "$(tr -d '[:space:]' < "${profile}/.ninjas-source-date-epoch")" == "1760572800" ]]; then ok "epoch marker recorded"; else bad "epoch marker wrong"; fi
if (( can_symlink )); then
  assert_absent "${profile}/.ninjas-profile-incomplete"
else
  assert_file "${profile}/.ninjas-profile-incomplete"
fi

printf '== idempotency\n'
first="$(cd -- "${profile}" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum)"
if "${ROOT_DIR}/scripts/prepare-profile.sh" --quiet >/dev/null 2>&1; then ok "second run exits 0"; else bad "second run failed"; fi
second="$(cd -- "${profile}" && find . -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum)"
if [[ "${first}" == "${second}" ]]; then ok "second run produced identical profile"; else bad "second run differs from first"; fi
if [[ "$(grep -c 'Ninjas OS overrides' "${pd}")" -eq 1 ]]; then ok "overrides appended exactly once"; else bad "overrides appended $(grep -c 'Ninjas OS overrides' "${pd}") times"; fi

printf '== failure modes\n'
if NINJAS_UPSTREAM_PROFILE="${TMP}/does-not-exist" "${ROOT_DIR}/scripts/prepare-profile.sh" >/dev/null 2>&1; then
  bad "missing upstream profile was not rejected"
else
  ok "missing upstream profile rejected"
fi
if msg="$(NINJAS_UPSTREAM_PROFILE="${TMP}/does-not-exist" "${ROOT_DIR}/scripts/prepare-profile.sh" 2>&1 || true)"; grep -q 'pacman -S --needed archiso' <<<"${msg}"; then
  ok "error message tells the user how to install archiso"
else
  bad "error message lacks install hint: ${msg}"
fi
# EUID is read-only in bash, so the root refusal cannot be simulated here;
# assert instead that every entry-point script calls the guard.
for script in prepare-profile.sh build-iso.sh check-prereqs.sh clean.sh; do
  if grep -q '^ninjas_require_not_root' "${ROOT_DIR}/scripts/${script}"; then
    ok "${script} refuses to run as root"
  else
    bad "${script} does not call ninjas_require_not_root"
  fi
done
# safe_rm_rf must refuse paths outside work/out.
if bash -c "source '${ROOT_DIR}/scripts/lib/common.sh'; ninjas_safe_rm_rf '${TMP}/upstream'" >/dev/null 2>&1; then
  bad "safe_rm_rf deleted a path outside work/ and out/"
else
  ok "safe_rm_rf refuses paths outside work/ and out/"
fi
if [[ -d "${TMP}/upstream" ]]; then ok "upstream still present after refusal"; else bad "upstream was deleted"; fi
if bash -c "source '${ROOT_DIR}/scripts/lib/common.sh'; ninjas_safe_rm_rf '${NINJAS_WORK_DIR}/../upstream'" >/dev/null 2>&1; then
  bad "safe_rm_rf accepted a path with '..'"
else
  ok "safe_rm_rf refuses '..' paths"
fi
# A symlink inside the overlay must be rejected.
if ln -s /etc/passwd "${TMP}/probe-link" 2>/dev/null && [[ -L "${TMP}/probe-link" ]]; then
  rm -f "${TMP}/probe-link"
  ovl="${TMP}/overlay-with-link"
  cp -a -- "${ROOT_DIR}/profile-overlay" "${ovl}"
  ln -s /etc/passwd "${ovl}/airootfs/etc/bad-link"
  if NINJAS_ROOT_DIR="${TMP}/fake-root" bash -c "
      mkdir -p '${TMP}/fake-root'
      ln -sfn '${ROOT_DIR}/config' '${TMP}/fake-root/config'
      ln -sfn '${ovl}' '${TMP}/fake-root/profile-overlay'
      ln -sfn '${ROOT_DIR}/scripts' '${TMP}/fake-root/scripts'
      '${ROOT_DIR}/scripts/prepare-profile.sh'" >/dev/null 2>&1; then
    bad "overlay containing a symlink was accepted"
  else
    ok "overlay containing a symlink is rejected"
  fi
else
  skip "cannot create symlinks; overlay-symlink rejection test skipped"
fi

printf '\n%d passed, %d failed, %d skipped\n' "${pass}" "${fail}" "${skip}"
(( keep )) && printf 'kept: %s\n' "${TMP}"
(( fail == 0 ))
