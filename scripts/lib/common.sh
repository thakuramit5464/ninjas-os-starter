#!/usr/bin/env bash
# Shared helpers for Ninjas OS build scripts. Source this file; do not run it.
#
# Every script that sources this gets:
#   - strict mode (set -Eeuo pipefail) with an error trap that names the line,
#   - colour-aware log/warn/die helpers,
#   - NINJAS_ROOT_DIR / NINJAS_WORK_DIR / NINJAS_OUT_DIR / NINJAS_PROFILE_DIR,
#   - the metadata from config/ninjas-os.conf,
#   - path-safety helpers used before any recursive deletion.
#
# Environment overrides (mainly for tests):
#   NINJAS_ROOT_DIR          repository root (default: parent of scripts/)
#   NINJAS_WORK_DIR          scratch directory (default: $NINJAS_ROOT_DIR/work)
#   NINJAS_OUT_DIR           ISO output directory (default: $NINJAS_ROOT_DIR/out)
#   NINJAS_UPSTREAM_PROFILE  Archiso profile to copy
#                            (default: /usr/share/archiso/configs/releng)

if [[ -n "${_NINJAS_COMMON_SH_LOADED:-}" ]]; then
  return 0
fi
_NINJAS_COMMON_SH_LOADED=1

set -Eeuo pipefail
shopt -s nullglob

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  _c_info=$'\033[1;34m'; _c_ok=$'\033[1;32m'; _c_warn=$'\033[1;33m'
  _c_err=$'\033[1;31m'; _c_off=$'\033[0m'
else
  _c_info=''; _c_ok=''; _c_warn=''; _c_err=''; _c_off=''
fi

log()  { printf '%s==>%s %s\n' "${_c_info}" "${_c_off}" "$*" >&2; }
ok()   { printf '%s  ✔%s %s\n' "${_c_ok}" "${_c_off}" "$*" >&2; }
warn() { printf '%sWARNING:%s %s\n' "${_c_warn}" "${_c_off}" "$*" >&2; }
die()  { printf '%sERROR:%s %s\n' "${_c_err}" "${_c_off}" "$*" >&2; exit 1; }

_ninjas_on_error() {
  local rc=$? line=$1 cmd=$2
  printf '%sERROR:%s %s failed at line %s: %s (exit %s)\n' \
    "${_c_err}" "${_c_off}" "${BASH_SOURCE[1]:-script}" "${line}" "${cmd}" "${rc}" >&2
  exit "${rc}"
}
trap '_ninjas_on_error "${LINENO}" "${BASH_COMMAND}"' ERR

# ---------------------------------------------------------------------------
# Locations
# ---------------------------------------------------------------------------
_common_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
NINJAS_ROOT_DIR="${NINJAS_ROOT_DIR:-$(cd -- "${_common_dir}/../.." && pwd)}"
NINJAS_WORK_DIR="${NINJAS_WORK_DIR:-${NINJAS_ROOT_DIR}/work}"
NINJAS_OUT_DIR="${NINJAS_OUT_DIR:-${NINJAS_ROOT_DIR}/out}"
NINJAS_PROFILE_DIR="${NINJAS_WORK_DIR}/profile"
NINJAS_BUILD_DIR="${NINJAS_WORK_DIR}/build"
NINJAS_UPSTREAM_PROFILE="${NINJAS_UPSTREAM_PROFILE:-/usr/share/archiso/configs/releng}"
NINJAS_CONFIG_DIR="${NINJAS_ROOT_DIR}/config"
NINJAS_OVERLAY_DIR="${NINJAS_ROOT_DIR}/profile-overlay/airootfs"
NINJAS_TEMPLATE_DIR="${NINJAS_ROOT_DIR}/profile-overlay/templates"
export NINJAS_ROOT_DIR NINJAS_WORK_DIR NINJAS_OUT_DIR NINJAS_PROFILE_DIR \
  NINJAS_BUILD_DIR NINJAS_UPSTREAM_PROFILE NINJAS_CONFIG_DIR \
  NINJAS_OVERLAY_DIR NINJAS_TEMPLATE_DIR

# ---------------------------------------------------------------------------
# Metadata (config/ninjas-os.conf)
# ---------------------------------------------------------------------------
ninjas_load_config() {
  local conf="${NINJAS_CONFIG_DIR}/ninjas-os.conf"
  [[ -r "${conf}" ]] || die "missing config file: ${conf}"
  # Refuse anything that is not a plain KEY="value" line, a comment or blank,
  # so a malicious or broken config cannot execute code when sourced.
  local bad
  bad="$(grep -Ev '^[[:space:]]*(#|$)|^[A-Z_][A-Z0-9_]*="[^"$`\\]*"[[:space:]]*$' "${conf}" || true)"
  [[ -z "${bad}" ]] || die "config/ninjas-os.conf contains unsupported lines:"$'\n'"${bad}"
  # shellcheck disable=SC1090
  source "${conf}"
  local required=(NINJAS_OS_NAME NINJAS_OS_ID NINJAS_OS_VERSION NINJAS_OS_CODENAME
    NINJAS_ISO_NAME NINJAS_ISO_LABEL_PREFIX NINJAS_ISO_PUBLISHER
    NINJAS_ISO_APPLICATION NINJAS_LIVE_USER)
  local key
  for key in "${required[@]}"; do
    [[ -n "${!key:-}" ]] || die "config/ninjas-os.conf: ${key} is not set"
  done
  [[ "${NINJAS_ISO_NAME}" =~ ^[a-z0-9][a-z0-9._-]*$ ]] \
    || die "NINJAS_ISO_NAME must be lowercase alphanumerics, dots, dashes or underscores"
  [[ "${NINJAS_ISO_LABEL_PREFIX}" =~ ^[A-Z0-9_]{1,24}$ ]] \
    || die "NINJAS_ISO_LABEL_PREFIX must be 1-24 uppercase alphanumerics/underscores"
  [[ "${NINJAS_OS_VERSION}" =~ ^[A-Za-z0-9.+-]+$ ]] \
    || die "NINJAS_OS_VERSION may only contain alphanumerics, dots, plus and dash"
  [[ "${NINJAS_LIVE_USER}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
    || die "NINJAS_LIVE_USER is not a valid POSIX user name"
}

# ---------------------------------------------------------------------------
# Path safety
# ---------------------------------------------------------------------------
# ninjas_path_is_inside <path> <parent>: true when <path> is <parent> or a
# descendant of it. Both must be absolute. No filesystem access is needed.
ninjas_path_is_inside() {
  local path=$1 parent=$2
  [[ "${path}" == /* && "${parent}" == /* ]] || return 1
  path="${path%/}"; parent="${parent%/}"
  [[ "${path}" == "${parent}" || "${path}" == "${parent}"/* ]]
}

# ninjas_safe_rm_rf <path> [--sudo]
# Removes <path> recursively, but only when it is a non-symlink directory
# strictly inside NINJAS_WORK_DIR or NINJAS_OUT_DIR. Anything else is fatal.
ninjas_safe_rm_rf() {
  local target=$1 use_sudo=${2:-}
  [[ -n "${target}" ]] || die "safe_rm_rf: empty path"
  [[ "${target}" == /* ]] || die "safe_rm_rf: refusing relative path: ${target}"
  [[ "${target}" != *..* ]] || die "safe_rm_rf: refusing path containing '..': ${target}"
  if [[ "${target%/}" == "${NINJAS_WORK_DIR%/}" || "${target%/}" == "${NINJAS_OUT_DIR%/}" ]]; then
    : # deleting the whole work/ or out/ dir is allowed
  elif ninjas_path_is_inside "${target}" "${NINJAS_WORK_DIR}" \
    || ninjas_path_is_inside "${target}" "${NINJAS_OUT_DIR}"; then
    :
  else
    die "safe_rm_rf: ${target} is outside ${NINJAS_WORK_DIR} and ${NINJAS_OUT_DIR}; refusing"
  fi
  [[ "${target%/}" != "/" && "${target%/}" != "${NINJAS_ROOT_DIR%/}" ]] \
    || die "safe_rm_rf: refusing to delete ${target}"
  [[ -L "${target}" ]] && die "safe_rm_rf: ${target} is a symlink; refusing"
  [[ -e "${target}" ]] || return 0
  if [[ "${use_sudo}" == "--sudo" ]]; then
    sudo rm -rf --one-file-system -- "${target}"
  else
    rm -rf --one-file-system -- "${target}"
  fi
}

ninjas_require_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    die "run this script as your normal user; it calls sudo itself only where root is required"
  fi
}

ninjas_require_cmd() {
  local cmd=$1 hint=${2:-}
  command -v "${cmd}" >/dev/null 2>&1 && return 0
  if [[ -n "${hint}" ]]; then
    die "required command not found: ${cmd}. ${hint}"
  fi
  die "required command not found: ${cmd}"
}

# ninjas_read_list <file>: print the non-comment, non-blank entries of a
# package-list style file, one per line, trimmed and with inline comments cut.
ninjas_read_list() {
  local file=$1
  [[ -r "${file}" ]] || die "cannot read list file: ${file}"
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' -- "${file}"
}

# ninjas_source_date_epoch: a stable timestamp for the whole build. Honours a
# caller-provided SOURCE_DATE_EPOCH, otherwise the current time.
ninjas_source_date_epoch() {
  if [[ -n "${SOURCE_DATE_EPOCH:-}" ]]; then
    [[ "${SOURCE_DATE_EPOCH}" =~ ^[0-9]+$ ]] || die "SOURCE_DATE_EPOCH must be an integer"
    printf '%s' "${SOURCE_DATE_EPOCH}"
  else
    date +%s
  fi
}

ninjas_git_revision() {
  if command -v git >/dev/null 2>&1 \
    && git -C "${NINJAS_ROOT_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    local rev dirty=""
    rev="$(git -C "${NINJAS_ROOT_DIR}" rev-parse --short=12 HEAD 2>/dev/null || printf 'unknown')"
    if [[ -n "$(git -C "${NINJAS_ROOT_DIR}" status --porcelain 2>/dev/null)" ]]; then
      dirty="-dirty"
    fi
    printf '%s%s' "${rev}" "${dirty}"
  else
    printf 'no-git'
  fi
}
