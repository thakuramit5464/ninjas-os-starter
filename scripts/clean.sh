#!/usr/bin/env bash
# Remove generated build artifacts. Deletion is restricted to the project's
# own work/ and out/ directories; anything else is refused.
#
# Usage: scripts/clean.sh [--out] [--dry-run]
#   (default)   remove work/ (prepared profile, mkarchiso build dir, logs)
#   --out       also remove out/ (built ISOs and release metadata)
#   --dry-run   only print what would be removed

# shellcheck source=lib/common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/common.sh"

clean_out=0 dry_run=0
for arg in "$@"; do
  case "${arg}" in
    --out) clean_out=1 ;;
    --dry-run) dry_run=1 ;;
    -h|--help)
      sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "unknown argument: ${arg} (try --help)" ;;
  esac
done

ninjas_require_not_root

targets=("${NINJAS_WORK_DIR}")
(( clean_out )) && targets+=("${NINJAS_OUT_DIR}")

for t in "${targets[@]}"; do
  if [[ ! -e "${t}" ]]; then
    ok "${t} does not exist; nothing to do"
    continue
  fi
  if (( dry_run )); then
    log "would remove ${t}"
    continue
  fi
  # mkarchiso leaves root-owned files behind, so use sudo only when needed.
  if [[ -w "${t}" ]] && ! find "${t}" ! -user "$(id -u)" -print -quit 2>/dev/null | grep -q .; then
    ninjas_safe_rm_rf "${t}"
  else
    log "${t} contains root-owned files; removing with sudo"
    ninjas_safe_rm_rf "${t}" --sudo
  fi
  ok "removed ${t}"
done
