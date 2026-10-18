#!/usr/bin/env bash
# Validate that this machine can build the Ninjas OS ISO.
#
# Runs without root. Exit status is non-zero when a hard requirement is
# missing; warnings are printed for soft requirements (disk space, memory).
#
# Usage: scripts/check-prereqs.sh [--packages] [--quiet]
#   --packages  also verify every package in config/packages.extra.x86_64
#               exists in the synced pacman databases (needs pacman -Sy done)
#   --quiet     only print problems

# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

check_packages=0
quiet=0
for arg in "$@"; do
  case "${arg}" in
    --packages) check_packages=1 ;;
    --quiet|-q) quiet=1 ;;
    -h|--help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "unknown argument: ${arg} (try --help)" ;;
  esac
done
if (( quiet )); then
  ok() { :; }
  log() { :; }
fi

failures=0
# shellcheck disable=SC2154  # colour variables are set by lib/common.sh
problem() { printf '%sMISSING:%s %s\n' "${_c_err}" "${_c_off}" "$*" >&2; failures=$((failures + 1)); }

ninjas_require_not_root
ninjas_load_config

log "Checking build host"
if [[ -r /etc/arch-release ]] || { [[ -r /etc/os-release ]] && grep -Eq '^ID(_LIKE)?=.*arch' /etc/os-release; }; then
  ok "Arch Linux (or derivative) detected"
else
  problem "this does not look like Arch Linux. Build inside the Arch Linux VM (see docs/building.md)."
fi

log "Checking required commands"
declare -A hints=(
  [mkarchiso]="Install with: sudo pacman -S --needed archiso"
  [pacman]="pacman is required to query package metadata"
  [sudo]="Install with: pacman -S sudo (as root) and add your user to the wheel group"
  [sha256sum]="coreutils should provide sha256sum"
  [git]="Install with: sudo pacman -S --needed git"
)
for cmd in mkarchiso pacman sudo sha256sum; do
  if command -v "${cmd}" >/dev/null 2>&1; then
    ok "${cmd}"
  else
    problem "${cmd} not found. ${hints[${cmd}]}"
  fi
done
command -v git >/dev/null 2>&1 || warn "git not found; build metadata will not record a revision. ${hints[git]}"

if command -v pacman >/dev/null 2>&1; then
  archiso_ver="$(pacman -Q archiso 2>/dev/null | awk '{print $2}' || true)"
  if [[ -n "${archiso_ver}" ]]; then
    ok "archiso package version ${archiso_ver}"
  else
    problem "archiso package is not installed. Install with: sudo pacman -S --needed archiso"
  fi
fi

log "Checking upstream profile"
if [[ -d "${NINJAS_UPSTREAM_PROFILE}" && -f "${NINJAS_UPSTREAM_PROFILE}/profiledef.sh" \
  && -f "${NINJAS_UPSTREAM_PROFILE}/packages.x86_64" ]]; then
  ok "releng profile at ${NINJAS_UPSTREAM_PROFILE}"
else
  problem "Archiso releng profile not found at ${NINJAS_UPSTREAM_PROFILE}. Install with: sudo pacman -S --needed archiso"
fi

log "Checking sudo"
if command -v sudo >/dev/null 2>&1; then
  if sudo -n true 2>/dev/null; then
    ok "sudo works without a password prompt"
  else
    warn "sudo will prompt for your password when mkarchiso starts"
  fi
fi

log "Checking resources"
probe_dir="${NINJAS_WORK_DIR}"
while [[ ! -d "${probe_dir}" && "${probe_dir}" != "/" ]]; do probe_dir="$(dirname -- "${probe_dir}")"; done
free_kib="$(df -Pk -- "${probe_dir}" | awk 'NR==2 {print $4}')"
if [[ "${free_kib}" =~ ^[0-9]+$ ]]; then
  free_gib=$((free_kib / 1024 / 1024))
  if (( free_gib < 10 )); then
    problem "only ${free_gib} GiB free for ${NINJAS_WORK_DIR}; a KDE live ISO build needs at least 10 GiB (20 GiB recommended)"
  elif (( free_gib < 20 )); then
    warn "${free_gib} GiB free for ${NINJAS_WORK_DIR}; 20 GiB or more is recommended"
  else
    ok "${free_gib} GiB free for ${NINJAS_WORK_DIR}"
  fi
fi
if [[ -r /proc/meminfo ]]; then
  mem_kib="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
  mem_gib=$((mem_kib / 1024 / 1024))
  if (( mem_gib < 4 )); then
    warn "only ${mem_gib} GiB RAM; squashfs compression may be very slow or fail. 6-8 GiB recommended."
  else
    ok "${mem_gib} GiB RAM"
  fi
fi

if (( check_packages )); then
  log "Checking package names against pacman databases"
  if ! command -v pacman >/dev/null 2>&1; then
    problem "pacman not available; cannot validate package names"
  else
    missing=()
    while IFS= read -r pkg; do
      if pacman -Si -- "${pkg}" >/dev/null 2>&1; then
        ok "${pkg}"
      elif pacman -Sg -- "${pkg}" >/dev/null 2>&1; then
        ok "${pkg} (group)"
      else
        missing+=("${pkg}")
      fi
    done < <(ninjas_read_list "${NINJAS_CONFIG_DIR}/packages.extra.x86_64")
    if (( ${#missing[@]} > 0 )); then
      problem "packages not found in the synced databases: ${missing[*]}
  If the databases are stale run:  sudo pacman -Sy
  If a package was renamed or dropped (Arch is rolling release), update config/packages.extra.x86_64."
    fi
    # Removals must still exist upstream, otherwise the config is stale.
    while IFS= read -r pkg; do
      if grep -Eqx "[[:space:]]*${pkg}[[:space:]]*" "${NINJAS_UPSTREAM_PROFILE}/packages.x86_64" 2>/dev/null; then
        ok "removal target present upstream: ${pkg}"
      else
        warn "config/packages.remove.x86_64 lists ${pkg}, but upstream releng no longer ships it"
      fi
    done < <(ninjas_read_list "${NINJAS_CONFIG_DIR}/packages.remove.x86_64")
  fi
fi

if (( failures > 0 )); then
  die "${failures} prerequisite problem(s) found. Fix them and re-run scripts/check-prereqs.sh"
fi
ok "all prerequisites satisfied"
