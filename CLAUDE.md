# Claude Code Instructions — Ninjas OS

## Mission
Build Ninjas OS as a fully scripted, Arch-based Linux distribution. The initial deliverable is a reproducible Archiso live ISO that boots in a VM. Later milestones add custom branding and a permission-controlled AI desktop assistant.

## Repository map
- `config/` — the single source of truth for what makes the image Ninjas OS: `ninjas-os.conf` (name/version/ISO metadata/live user), `packages.extra.x86_64`, `packages.remove.x86_64`, `airootfs-symlinks` (service enablement), `upstream-units-disable`.
- `profile-overlay/airootfs/` — regular files copied into the image. **No symlinks** (they do not survive Windows checkouts); declare them in `config/airootfs-symlinks`.
- `profile-overlay/templates/` — `*.in` files rendered with `@NINJAS_*@` placeholders from `config/ninjas-os.conf`.
- `scripts/lib/common.sh` — strict mode, logging, config loader, `ninjas_safe_rm_rf` (only inside `work/` and `out/`).
- `scripts/prepare-profile.sh`, `build-iso.sh`, `check-prereqs.sh`, `clean.sh`.
- `tests/run-all.sh` — static checks + fixture-based prepare test; runs without root/Archiso. `tests/fixtures/fake-releng/profiledef.sh` mirrors upstream verbatim; update it when Archiso changes.
- `docs/upstream-deviations.md` — every change vs. upstream `releng` with its reason. Add a row for any new deviation.
- `specs/001-ninjas-os-foundation/` — spec, plan, tasks. `.specify/memory/constitution.md` — principles.

## First actions
1. Inspect the repository and report what exists before editing.
2. Read `.specify/memory/constitution.md`, the active spec, plan, and tasks.
3. Identify assumptions and risks. Ask only when a decision blocks safe progress.
4. Make a short implementation plan, then implement the smallest complete milestone.
5. Run `tests/run-all.sh` (and shellcheck when available). Report exact commands and results.

## Constraints
- Target build environment: Arch Linux VM hosted on Windows. The ISO cannot be built on Windows; say so instead of faking it.
- Base: official Arch Linux and Archiso `releng` profile. Verify package names and profile fields against the current repositories/profile; Arch is rolling release (example: Plasma 6.8 dropped `plasma-x11-session`).
- Use Bash for build scripts and Python for the first AI controller.
- Do not replace the upstream boot configuration without a documented need; copy upstream and append/override, never edit `/usr/share/archiso`.
- Do not claim an ISO was built or boot-tested unless it actually was. Keep the README verification table honest.
- Never write an ISO to a physical disk automatically.
- Keep generated artifacts in ignored `work/` and `out/` directories.
- Record build inputs (archiso version, SOURCE_DATE_EPOCH, git revision, package manifest); document that bit-for-bit reproducibility needs snapshot repositories.
- Do not add secrets, API keys, personal data, or credentials to the repository.
- Keep files LF; `tests/run-static-checks.sh` fails on CRLF.

## AI safety requirements
- The model must never receive unrestricted root access.
- The model must not directly execute arbitrary shell strings.
- Use a typed, allowlisted action schema and a separate policy validator.
- Require explicit confirmation for destructive, privileged, external-network, or privacy-sensitive actions.
- Use least privilege, clear action previews, timeouts, and audit logs.
- Fail closed when validation or policy evaluation fails.
- Make the AI agent optional and disabled by default until the user explicitly starts it.
- Never execute model-generated commands without parsing, validation, and policy checks.
- Design reference: `docs/ai-architecture.md`.

## Code quality
- Prefer small scripts with strict error handling (`set -Eeuo pipefail`); source `scripts/lib/common.sh`.
- Make scripts idempotent where practical (`prepare-profile.sh` rebuilds `work/profile` from scratch).
- Quote shell variables and validate paths; use `ninjas_safe_rm_rf` for any recursive deletion.
- Add tests for package/profile preparation and AI action policy.
- Keep README, docs, spec, plan and tasks current.

## Completion report
For each milestone, summarize:
- files changed;
- commands run;
- tests/builds that actually passed;
- limitations and unverified behavior;
- exact next command for the user.
