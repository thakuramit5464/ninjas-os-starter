#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${ROOT_DIR}/work"
PROFILE_DIR="${WORK_DIR}/profile"
UPSTREAM_PROFILE="/usr/share/archiso/configs/releng"
OVERLAY_DIR="${ROOT_DIR}/profile-overlay/airootfs"
EXTRA_PACKAGES="${ROOT_DIR}/config/packages.extra.x86_64"

if [[ "${EUID}" -eq 0 ]]; then
  echo "Run prepare-profile.sh as your normal user, not with sudo." >&2
  exit 1
fi

if [[ ! -d "${UPSTREAM_PROFILE}" ]]; then
  echo "Archiso releng profile not found at ${UPSTREAM_PROFILE}." >&2
  echo "Install it with: sudo pacman -S --needed archiso" >&2
  exit 1
fi

mkdir -p "${WORK_DIR}"
rm -rf "${PROFILE_DIR}"
cp -a "${UPSTREAM_PROFILE}" "${PROFILE_DIR}"

# Add the project's packages without replacing the upstream package list.
cat "${EXTRA_PACKAGES}" >> "${PROFILE_DIR}/packages.x86_64"

# Overlay Ninjas OS files onto the upstream airootfs.
cp -a "${OVERLAY_DIR}/." "${PROFILE_DIR}/airootfs/"

# Give the image a custom label/version in profiledef.sh when those variables exist.
# Keep the upstream profile's boot mode and image settings intact.
if grep -q '^iso_name=' "${PROFILE_DIR}/profiledef.sh"; then
  sed -i 's/^iso_name=.*/iso_name="ninjas-os"/' "${PROFILE_DIR}/profiledef.sh"
fi
if grep -q '^iso_label=' "${PROFILE_DIR}/profiledef.sh"; then
  sed -i 's/^iso_label=.*/iso_label="NINJAS_OS"/' "${PROFILE_DIR}/profiledef.sh"
fi
if grep -q '^iso_publisher=' "${PROFILE_DIR}/profiledef.sh"; then
  sed -i 's/^iso_publisher=.*/iso_publisher="Ninjas OS Project"/' "${PROFILE_DIR}/profiledef.sh"
fi
if grep -q '^iso_application=' "${PROFILE_DIR}/profiledef.sh"; then
  sed -i 's/^iso_application=.*/iso_application="Ninjas OS Live ISO"/' "${PROFILE_DIR}/profiledef.sh"
fi

echo "Prepared profile at: ${PROFILE_DIR}"
echo "Review ${PROFILE_DIR}/profiledef.sh and packages.x86_64 before building."
