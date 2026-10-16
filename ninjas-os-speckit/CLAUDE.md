# Claude Code Instructions — Ninjas OS

## Mission
Build Ninjas OS as a fully scripted, Arch-based Linux distribution. The initial deliverable is a reproducible Archiso live ISO that boots in a VM. Later milestones add custom branding and a permission-controlled AI desktop assistant.

## First actions
1. Inspect the entire repository and report what exists before editing.
2. Read `.specify/memory/constitution.md`, the active spec, plan, and tasks.
3. Identify assumptions and risks. Ask only when a decision blocks safe progress.
4. Make a short implementation plan, then implement the smallest complete milestone.
5. Run relevant syntax checks, tests, and build validation. Report exact commands and results.

## Constraints
- Target build environment: Arch Linux VM hosted on Windows.
- Base: official Arch Linux and Archiso `releng` profile.
- Use Bash for build scripts and Python for the first AI controller.
- Do not manually replace the upstream boot configuration without a documented need.
- Do not claim an ISO was built or boot-tested unless it was actually built or tested.
- Never write an ISO to a physical disk automatically.
- Keep generated artifacts in ignored `work/` and `out/` directories.
- Pin or record build inputs where practical; document that Arch is rolling release and fully bit-for-bit reproducible output may require snapshot repositories.
- Do not add secrets, API keys, personal data, or credentials to the repository.

## AI safety requirements
- The model must never receive unrestricted root access.
- The model must not directly execute arbitrary shell strings.
- Use a typed, allowlisted action schema and a separate policy validator.
- Require explicit confirmation for destructive, privileged, external-network, or privacy-sensitive actions.
- Use least privilege, clear action previews, timeouts, and audit logs.
- Fail closed when validation or policy evaluation fails.
- Make the AI agent optional and disable it by default until the user explicitly starts it.
- Never execute model-generated commands without parsing, validation, and policy checks.

## Code quality
- Prefer small scripts with strict error handling (`set -Eeuo pipefail`).
- Make scripts idempotent where practical.
- Quote shell variables and validate paths.
- Avoid unsafe recursive deletion; constrain cleanup to known project-owned directories.
- Add tests for package/profile preparation and AI action policy.
- Keep user-facing documentation current.

## Completion report
For each milestone, summarize:
- files changed;
- commands run;
- tests/builds that actually passed;
- limitations and unverified behavior;
- exact next command for the user.
