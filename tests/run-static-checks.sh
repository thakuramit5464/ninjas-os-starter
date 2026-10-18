#!/usr/bin/env bash
# Static checks that run anywhere bash exists (Windows Git Bash, Arch VM, CI).
# No root, no network, no Archiso required.
#
#   - bash -n on every shell script
#   - shellcheck when installed (skipped with a notice otherwise)
#   - no CRLF line endings in scripts, config or overlay
#   - overlay sanity: no symlinks, no files where systemd expects symlinks,
#     unit files have the expected sections, scripts use strict mode
#   - config lists are well-formed
#   - templates only use known placeholders
#   - git diff --check when inside a git checkout
#
# Usage: tests/run-static-checks.sh

set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "${ROOT_DIR}"

pass=0 fail=0 skip=0
ok()   { printf '  PASS  %s\n' "$*"; pass=$((pass + 1)); }
bad()  { printf '  FAIL  %s\n' "$*" >&2; fail=$((fail + 1)); }
skip() { printf '  SKIP  %s\n' "$*"; skip=$((skip + 1)); }
section() { printf '\n== %s\n' "$*"; }

# --------------------------------------------------------------------------
section "shell syntax (bash -n)"
mapfile -t shell_files < <(
  find scripts tests profile-overlay/airootfs/usr/local/bin -type f \
    \( -name '*.sh' -o -path '*/usr/local/bin/*' \) | sort
  printf '%s\n' tests/fixtures/fake-releng/profiledef.sh
)
for f in "${shell_files[@]}"; do
  if bash -n "${f}" 2>/tmp/ninjas-bash-n.$$; then
    ok "${f}"
  else
    bad "${f}: $(cat /tmp/ninjas-bash-n.$$)"
  fi
done
rm -f /tmp/ninjas-bash-n.$$

# --------------------------------------------------------------------------
section "shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
  sc_targets=()
  for f in "${shell_files[@]}"; do
    [[ "${f}" == tests/fixtures/* ]] && continue
    sc_targets+=("${f}")
  done
  if shellcheck --shell=bash --external-sources --severity=warning "${sc_targets[@]}"; then
    ok "shellcheck clean (${#sc_targets[@]} files)"
  else
    bad "shellcheck reported problems"
  fi
else
  skip "shellcheck not installed (sudo pacman -S shellcheck)"
fi

# --------------------------------------------------------------------------
section "line endings and executability"
# grep on MSYS/Git Bash strips carriage returns before matching, so inspect
# bytes with od instead; it is portable and the files are small.
crlf_files=()
while IFS= read -r f; do
  if od -An -c -- "${f}" | grep -qF '\r'; then
    crlf_files+=("${f}")
  fi
done < <(find scripts tests config profile-overlay docs README.md CLAUDE.md .specify specs -type f   ! -path 'tests/.tmp/*' ! -name '*.png' ! -name '*.jpg' | sort)
if (( ${#crlf_files[@]} > 0 )); then
  bad "CRLF line endings found in: ${crlf_files[*]}"
else
  ok "no CRLF line endings"
fi
for f in scripts/*.sh tests/*.sh profile-overlay/airootfs/usr/local/bin/*; do
  if head -n1 "${f}" | grep -q '^#!/usr/bin/env bash$'; then
    ok "shebang: ${f}"
  else
    bad "${f} must start with #!/usr/bin/env bash"
  fi
  if grep -Eq '^set -Eeuo pipefail|source .*lib/common\.sh' "${f}"; then
    ok "strict mode: ${f}"
  else
    bad "${f} does not enable strict mode (set -Eeuo pipefail) or source lib/common.sh"
  fi
done

# --------------------------------------------------------------------------
section "overlay sanity"
overlay="profile-overlay/airootfs"
if links="$(find "${overlay}" -type l)"; [[ -n "${links}" ]]; then
  bad "symlinks in overlay (declare them in config/airootfs-symlinks): ${links}"
else
  ok "no symlinks committed in overlay"
fi
# Regular files in these places mean a symlink was flattened into text.
if flattened="$(find "${overlay}/etc/systemd/system" -type f \
  \( -path '*.wants/*' -o -path '*.requires/*' -o -name 'default.target' -o -name 'display-manager.service' \) 2>/dev/null)"; [[ -n "${flattened}" ]]; then
  bad "regular files where systemd expects symlinks: ${flattened}"
else
  ok "no flattened systemd symlinks"
fi
# Catch any small one-line file that is just a path (flattened symlink).
while IFS= read -r f; do
  if [[ "$(wc -l < "${f}")" -le 1 ]] && grep -Eq '^(/|\.\./)[^[:space:]]+$' "${f}"; then
    bad "${f} looks like a flattened symlink (its only content is a path)"
  fi
done < <(find "${overlay}" -type f -size -256c)
ok "no flattened-symlink-looking files"
for unit in "${overlay}"/etc/systemd/system/*.service; do
  if grep -q '^\[Unit\]' "${unit}" && grep -q '^\[Service\]' "${unit}" && grep -q '^ExecStart=' "${unit}"; then
    ok "unit structure: ${unit}"
  else
    bad "${unit} lacks [Unit]/[Service]/ExecStart"
  fi
  exec_path="$(sed -n 's/^ExecStart=\([^ ]*\).*/\1/p' "${unit}" | head -n1)"
  if [[ -f "${overlay}${exec_path}" ]] || [[ "${exec_path}" == /usr/bin/* ]]; then
    ok "ExecStart target exists: ${exec_path}"
  else
    bad "${unit}: ExecStart ${exec_path} is not shipped in the overlay"
  fi
done
if [[ -f "${overlay}/etc/sudoers.d/99-ninjas-live" ]] \
  && grep -Eq '^ninja ALL=\(ALL:ALL\) NOPASSWD: ALL$' "${overlay}/etc/sudoers.d/99-ninjas-live"; then
  ok "sudoers.d live rule present"
else
  bad "sudoers.d/99-ninjas-live missing or malformed"
fi
if command -v visudo >/dev/null 2>&1; then
  if visudo -cqf "${overlay}/etc/sudoers.d/99-ninjas-live"; then ok "visudo -c"; else bad "visudo rejects sudoers.d/99-ninjas-live"; fi
else
  skip "visudo not available for sudoers syntax check"
fi
if grep -q '^\[Autologin\]' "${overlay}/etc/sddm.conf.d/10-ninjas-live.conf" \
  && grep -q '^Session=plasma$' "${overlay}/etc/sddm.conf.d/10-ninjas-live.conf"; then
  ok "sddm autologin config"
else
  bad "sddm.conf.d/10-ninjas-live.conf missing [Autologin] or Session=plasma"
fi
# Live user name must agree between config, sudoers and sddm.
live_user="$(sed -n 's/^NINJAS_LIVE_USER="\(.*\)"$/\1/p' config/ninjas-os.conf)"
if grep -q "^${live_user} ALL=" "${overlay}/etc/sudoers.d/99-ninjas-live" \
  && grep -q "^User=${live_user}$" "${overlay}/etc/sddm.conf.d/10-ninjas-live.conf"; then
  ok "live user '${live_user}' consistent across config, sudoers and sddm"
else
  bad "live user name differs between config/ninjas-os.conf, sudoers.d and sddm.conf.d"
fi

# --------------------------------------------------------------------------
section "config lists"
strip() { sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; }
for list in config/packages.extra.x86_64 config/packages.remove.x86_64; do
  if badpkg="$(strip "${list}" | grep -Ev '^[a-z0-9@._+-]+$')"; [[ -n "${badpkg}" ]]; then
    bad "${list}: invalid package names: ${badpkg//$'\n'/, }"
  else
    ok "${list}: $(strip "${list}" | wc -l | tr -d ' ') valid entries"
  fi
done
if dup="$(strip config/packages.extra.x86_64 | sort | uniq -d)"; [[ -n "${dup}" ]]; then
  bad "duplicate entries in packages.extra.x86_64: ${dup//$'\n'/, }"
else
  ok "no duplicate packages in packages.extra.x86_64"
fi
if strip config/packages.extra.x86_64 | grep -qx 'plasma-x11-session'; then
  bad "plasma-x11-session no longer exists in Arch (Plasma 6.8 is Wayland-only)"
fi
if badlink="$(strip config/airootfs-symlinks | awk 'NF != 2 || $1 !~ /^\// || $1 ~ /\.\./ || $2 ~ /\.\./')"; [[ -n "${badlink}" ]]; then
  bad "config/airootfs-symlinks malformed lines: ${badlink}"
else
  ok "config/airootfs-symlinks: $(strip config/airootfs-symlinks | wc -l | tr -d ' ') well-formed entries"
fi
if badunit="$(strip config/upstream-units-disable | grep -Ev '^/[^[:space:]]+$' | grep -v '^$' || true; strip config/upstream-units-disable | grep '\.\.' || true)"; [[ -n "${badunit}" ]]; then
  bad "config/upstream-units-disable malformed lines: ${badunit}"
else
  ok "config/upstream-units-disable well-formed"
fi
# Every symlink that enables a unit we ship must point at a unit that exists
# in the overlay (for /etc targets).
while read -r link target; do
  if [[ "${target}" == /etc/* && ! -f "${overlay}${target}" ]]; then
    bad "symlink ${link} targets ${target} which is not in the overlay"
  fi
done < <(strip config/airootfs-symlinks)
ok "declared /etc symlink targets exist in overlay"
if badconf="$(grep -Ev '^[[:space:]]*(#|$)|^[A-Z_][A-Z0-9_]*="[^"$`\\]*"[[:space:]]*$' config/ninjas-os.conf)"; [[ -n "${badconf}" ]]; then
  bad "config/ninjas-os.conf has unsupported lines: ${badconf}"
else
  ok "config/ninjas-os.conf is plain KEY=\"value\""
fi

# --------------------------------------------------------------------------
section "templates"
known='NINJAS_OS_NAME|NINJAS_OS_ID|NINJAS_OS_VERSION|NINJAS_OS_CODENAME|NINJAS_OS_CODENAME_LOWER|NINJAS_OS_HOME_URL|NINJAS_BUILD_DATE|NINJAS_SOURCE_DATE_EPOCH|NINJAS_ARCHISO_VERSION|NINJAS_GIT_REVISION|NINJAS_LIVE_USER'
for tpl in $(find profile-overlay/templates -type f -name '*.in' | sort); do
  if unknown="$(grep -oE '@[A-Z_]+@' "${tpl}" | sort -u | grep -Ev "^@(${known})@$")"; [[ -n "${unknown}" ]]; then
    bad "${tpl}: unknown placeholders ${unknown//$'\n'/, }"
  else
    ok "${tpl}"
  fi
done

# --------------------------------------------------------------------------
section "git"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git diff --check >/dev/null 2>&1 && git diff --cached --check >/dev/null 2>&1; then
    ok "git diff --check (no whitespace errors)"
  else
    bad "git diff --check reported whitespace problems"
  fi
  if tracked_iso="$(git ls-files -- '*.iso' 'work/' 'out/')"; [[ -n "${tracked_iso}" ]]; then
    bad "generated artifacts are tracked by git: ${tracked_iso}"
  else
    ok "no generated artifacts tracked"
  fi
else
  skip "not a git checkout"
fi

# --------------------------------------------------------------------------
printf '\n%d passed, %d failed, %d skipped\n' "${pass}" "${fail}" "${skip}"
(( fail == 0 ))
