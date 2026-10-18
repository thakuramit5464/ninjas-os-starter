#!/usr/bin/env bash
# Build the Ninjas OS live ISO with mkarchiso.
#
# Runs as a normal user and uses sudo only for mkarchiso (which needs root to
# pacstrap and build the squashfs) and for cleaning the root-owned build dir.
# Output goes to out/ only. Nothing is ever written to a physical disk.
#
# Usage: scripts/build-iso.sh [options]
#   --skip-prepare        reuse the existing work/profile instead of re-preparing
#   --skip-package-check  do not validate package names with pacman first
#   --keep-build-dir      do not wipe work/build before building (faster, but
#                         mkarchiso may reuse stale stages)
#   --dry-run             print the mkarchiso command without running it
#   -h, --help            show this help
# Env:
#   SOURCE_DATE_EPOCH     fix the build timestamp (recorded in build-info)

# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

skip_prepare=0 skip_pkg_check=0 keep_build=0 dry_run=0
for arg in "$@"; do
  case "${arg}" in
    --skip-prepare) skip_prepare=1 ;;
    --skip-package-check) skip_pkg_check=1 ;;
    --keep-build-dir) keep_build=1 ;;
    --dry-run) dry_run=1 ;;
    -h|--help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "unknown argument: ${arg} (try --help)" ;;
  esac
done

ninjas_require_not_root
ninjas_load_config

scripts_dir="${NINJAS_ROOT_DIR}/scripts"
profile="${NINJAS_PROFILE_DIR}"
build_dir="${NINJAS_BUILD_DIR}"
out_dir="${NINJAS_OUT_DIR}"
log_dir="${NINJAS_WORK_DIR}/logs"

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------
if (( ! dry_run )); then
  prereq_args=()
  (( skip_pkg_check )) || prereq_args+=(--packages)
  "${scripts_dir}/check-prereqs.sh" "${prereq_args[@]}" --quiet \
    || die "prerequisite check failed; run scripts/check-prereqs.sh for details"
fi

# ---------------------------------------------------------------------------
# Profile
# ---------------------------------------------------------------------------
if (( skip_prepare )); then
  [[ -f "${profile}/profiledef.sh" ]] \
    || die "--skip-prepare given but ${profile} is not prepared; run scripts/prepare-profile.sh"
  log "Reusing prepared profile at ${profile}"
else
  "${scripts_dir}/prepare-profile.sh"
fi

[[ ! -e "${profile}/.ninjas-profile-incomplete" ]]   || die "${profile} was prepared with NINJAS_SKIP_SYMLINKS=1 and is incomplete; re-run scripts/prepare-profile.sh on a filesystem that supports symlinks"

epoch_file="${profile}/.ninjas-source-date-epoch"
if [[ -r "${epoch_file}" ]]; then
  epoch="$(tr -d '[:space:]' < "${epoch_file}")"
  [[ "${epoch}" =~ ^[0-9]+$ ]] || die "corrupt ${epoch_file}"
else
  epoch="$(ninjas_source_date_epoch)"
fi
export SOURCE_DATE_EPOCH="${epoch}"

# Read the final metadata exactly as mkarchiso will.
profile_meta="$(
  set -e
  # shellcheck disable=SC2034  # populated by the sourced profiledef.sh
  declare -A file_permissions
  # shellcheck disable=SC1090
  source "${profile}/profiledef.sh"
  # shellcheck disable=SC2154  # iso_* come from profiledef.sh
  printf '%s|%s|%s|%s\n' "${iso_name}" "${iso_version}" "${iso_label}" "${install_dir:-arch}"
)"
IFS='|' read -r iso_name iso_version iso_label install_dir <<<"${profile_meta}"
arch="$(uname -m)"
expected_iso="${out_dir}/${iso_name}-${iso_version}-${arch}.iso"

# ---------------------------------------------------------------------------
# Workspace
# ---------------------------------------------------------------------------
mkdir -p -- "${out_dir}" "${log_dir}"
if (( ! keep_build )) && [[ -e "${build_dir}" ]]; then
  log "Removing previous build directory ${build_dir} (needs sudo; files are root-owned)"
  (( dry_run )) || ninjas_safe_rm_rf "${build_dir}" --sudo
fi
mkdir -p -- "${build_dir}"

build_log="${log_dir}/mkarchiso-$(date -u --date="@${epoch}" +%Y%m%d-%H%M%S).log"
cmd=(sudo env "SOURCE_DATE_EPOCH=${epoch}" mkarchiso -v -w "${build_dir}" -o "${out_dir}" "${profile}")

log "Build plan"
printf '  profile:    %s\n  work dir:   %s\n  output:     %s\n  expected:   %s\n  log:        %s\n  command:    %s\n' \
  "${profile}" "${build_dir}" "${out_dir}" "${expected_iso}" "${build_log}" "${cmd[*]}" >&2

if (( dry_run )); then
  ok "dry run; nothing executed"
  exit 0
fi

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
log "Running mkarchiso (downloads packages; this takes a while)"
start_ts="$(date +%s)"
if ! "${cmd[@]}" 2>&1 | tee -- "${build_log}"; then
  die "mkarchiso failed. Full log: ${build_log}
Common causes: stale pacman databases (sudo pacman -Syu), a renamed or
removed package in config/packages.extra.x86_64 (scripts/check-prereqs.sh --packages),
or not enough disk space in ${NINJAS_WORK_DIR}."
fi
elapsed=$(( $(date +%s) - start_ts ))

[[ -f "${expected_iso}" ]] || die "mkarchiso finished but ${expected_iso} does not exist. Check ${build_log}."

# ---------------------------------------------------------------------------
# Release metadata (checksum, package manifest, build info)
# ---------------------------------------------------------------------------
log "Writing release metadata"
# mkarchiso writes output as root; hand it back to the invoking user so the
# ISO can be copied or deleted without sudo. Constrained to out/.
sudo chown -- "$(id -u):$(id -g)" "${out_dir}" "${expected_iso}"

iso_base="${expected_iso%.iso}"
(cd -- "${out_dir}" && sha256sum -- "$(basename -- "${expected_iso}")" > "${iso_base}.sha256")

pkglist_src="${build_dir}/iso/${install_dir}/pkglist.${arch}.txt"
if sudo test -r "${pkglist_src}"; then
  # The redirect deliberately runs as the invoking user so out/ stays user-owned.
  # shellcheck disable=SC2024
  sudo cat -- "${pkglist_src}" > "${iso_base}.pkglist.txt"
else
  warn "package manifest not found at ${pkglist_src}; skipping"
fi

{
  printf 'iso=%s\n' "$(basename -- "${expected_iso}")"
  printf 'size_bytes=%s\n' "$(stat -c %s -- "${expected_iso}")"
  printf 'sha256=%s\n' "$(cut -d' ' -f1 -- "${iso_base}.sha256")"
  printf 'iso_name=%s\niso_version=%s\niso_label=%s\narch=%s\n' "${iso_name}" "${iso_version}" "${iso_label}" "${arch}"
  printf 'ninjas_os_version=%s\nninjas_os_codename=%s\n' "${NINJAS_OS_VERSION}" "${NINJAS_OS_CODENAME}"
  printf 'source_date_epoch=%s\nbuild_date_utc=%s\n' "${epoch}" "$(date -u --date="@${epoch}" +%Y-%m-%dT%H:%M:%SZ)"
  printf 'build_seconds=%s\n' "${elapsed}"
  printf 'archiso_version=%s\n' "$(pacman -Q archiso 2>/dev/null | awk '{print $2}' || printf unknown)"
  printf 'build_host_kernel=%s\n' "$(uname -r)"
  printf 'git_revision=%s\n' "$(ninjas_git_revision)"
  printf 'upstream_profile=%s\n' "${NINJAS_UPSTREAM_PROFILE}"
  printf 'log=%s\n' "${build_log}"
} > "${iso_base}.build-info.txt"

ok "ISO:          ${expected_iso} ($(( $(stat -c %s -- "${expected_iso}") / 1024 / 1024 )) MiB)"
ok "checksum:     ${iso_base}.sha256"
ok "manifest:     ${iso_base}.pkglist.txt"
ok "build info:   ${iso_base}.build-info.txt"
ok "build time:   ${elapsed}s"
printf '\nNext: boot the ISO in a disposable VM (docs/vm-testing.md). Never write it to a disk without verifying the target device.\n' >&2
