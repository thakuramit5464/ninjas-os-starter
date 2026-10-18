#!/usr/bin/env bash
# Run every automated check that does not need root or Archiso.
# Usage: tests/run-all.sh
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

status=0
for t in "${ROOT_DIR}/tests/run-static-checks.sh" "${ROOT_DIR}/tests/test-prepare-profile.sh"; do
  printf '\n######## %s\n' "${t#"${ROOT_DIR}"/}"
  if ! bash "${t}"; then
    status=1
    printf '######## FAILED: %s\n' "${t#"${ROOT_DIR}"/}" >&2
  fi
done

if (( status == 0 )); then
  printf '\nAll automated checks passed. The ISO build itself (scripts/build-iso.sh) and the VM boot test still have to run in the Arch VM.\n'
else
  printf '\nSome checks FAILED.\n' >&2
fi
exit "${status}"
