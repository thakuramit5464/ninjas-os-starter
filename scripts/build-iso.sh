#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/work"
PROFILE_DIR="${WORK_DIR}/profile"
OUT_DIR="${ROOT_DIR}/out"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run this script as your normal user. It will use sudo only for mkarchiso." >&2
  exit 1
fi

command -v mkarchiso >/dev/null 2>&1 || {
  echo "mkarchiso not found. Install it with: sudo pacman -S --needed archiso" >&2
  exit 1
}

"${ROOT_DIR}/scripts/prepare-profile.sh"
mkdir -p "${OUT_DIR}" "${WORK_DIR}/build"

echo "Building Ninjas OS ISO. This may take a while and download packages."
sudo mkarchiso -v -w "${WORK_DIR}/build" -o "${OUT_DIR}" "${PROFILE_DIR}"

echo
echo "Build finished. ISO files:"
find "${OUT_DIR}" -maxdepth 1 -type f -name '*.iso' -printf '%p (%s bytes)\n'
