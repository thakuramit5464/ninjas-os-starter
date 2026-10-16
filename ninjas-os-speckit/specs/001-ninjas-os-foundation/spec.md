# Feature Specification: Ninjas OS Foundation and AI-Ready Desktop

**Status:** Draft  
**Feature branch suggestion:** `001-ninjas-os-foundation`

## 1. Summary
Create a fully scripted, Arch-based live Linux distribution called Ninjas OS. The first release boots into a usable desktop in a virtual machine and establishes a safe foundation for a future local AI assistant that can interpret user requests and perform explicitly authorized computer actions.

## 2. Problem
Manual OS customization is hard to reproduce, debug, share, and maintain. Ninjas OS needs a version-controlled build process that produces a bootable ISO and can evolve without losing safety or maintainability.

## 3. Goals
- Build a custom Archiso ISO using a scripted process.
- Use the official Archiso `releng` profile as the baseline.
- Provide a basic graphical desktop, terminal, networking, and useful diagnostics.
- Apply Ninjas OS branding and a welcome marker.
- Document VM testing and safe USB testing.
- Define an AI action architecture with strict policy enforcement before implementing broad computer control.

## 4. Non-goals for Alpha 0.1
- Writing a new Linux kernel, bootloader, package manager, or desktop environment.
- Replacing Windows or installing to the user's internal disk.
- Shipping an autonomous agent with unrestricted shell, root, or network access.
- Guaranteeing bit-for-bit reproducible builds from moving Arch repositories.
- Supporting every physical computer or graphics chipset.
- Including a large local AI model in the ISO.

## 5. Target environment
- Build host: Windows PC.
- Build environment: Arch Linux virtual machine.
- Output: x86_64 bootable live ISO.
- VM test target: VirtualBox or another UEFI-capable hypervisor.
- USB testing: optional later step using a separate USB device.

## 6. User stories
### US1 — Build from source
As a developer, I can run one documented command inside the Arch VM to generate the ISO so I do not need to manually assemble the live image.

**Acceptance criteria**
- Build script checks for required tools and profile files.
- Build stops with an actionable error if prerequisites are missing.
- The output ISO is written only under the repository's `out/` directory.
- Build workspace and output are excluded from Git.
- The script does not write to physical disks.

### US2 — Boot the live desktop
As a tester, I can boot the ISO in a VM and reach a graphical session.

**Acceptance criteria**
- The ISO boots in the target VM configuration.
- The expected desktop and terminal are available.
- Networking can be enabled using NetworkManager.
- The image displays Ninjas OS identity in at least one visible place.
- If graphical startup fails, logs and recovery commands are documented.

### US3 — Inspect the image
As a developer, I can inspect the package list and filesystem overlay before building.

**Acceptance criteria**
- Custom package additions are version-controlled.
- Custom overlay files are kept separate from the copied upstream profile.
- The build script reports the source profile and output path.
- The project documents the effects of live-user and autologin configuration.

### US4 — Add an AI controller safely
As a user, I can ask the future AI assistant to perform a supported action and see what it proposes before it executes.

**Acceptance criteria**
- Actions use a typed schema, not arbitrary command strings.
- A policy validator rejects unknown actions and malformed arguments.
- Sensitive actions require explicit confirmation.
- Denied actions are logged without exposing secrets.
- The model cannot bypass the policy validator or acquire root privileges directly.

### US5 — Test and recover
As a developer, I can validate changes in a VM and return to a known-good state.

**Acceptance criteria**
- Documentation recommends VM snapshots before risky changes.
- Shell scripts have syntax checks.
- Unit tests cover AI action validation once that module exists.
- Build claims clearly distinguish actual tests from expected behavior.

## 7. Functional requirements
- FR-001: Provide a scripted Archiso profile preparation step.
- FR-002: Build the ISO using `mkarchiso`.
- FR-003: Keep custom packages and overlays in the repository.
- FR-004: Set a Ninjas OS image name/label without unnecessarily replacing upstream boot files.
- FR-005: Include a desktop environment and terminal in the image.
- FR-006: Include networking and diagnostic tools.
- FR-007: Document VM boot verification and troubleshooting.
- FR-008: Keep AI functionality optional and disabled until implemented and explicitly started.
- FR-009: Future AI actions must pass policy validation and user-consent rules.
- FR-010: Never write to a physical disk as part of the build process.

## 8. Non-functional requirements
- NFR-001: A fresh build attempt must be possible by following the README on a supported Arch VM.
- NFR-002: Scripts must fail on errors and quote variable expansions.
- NFR-003: All generated artifacts must stay in ignored output directories.
- NFR-004: Documentation must call out rolling-release and reproducibility limitations.
- NFR-005: AI data sharing must be local-first and opt-in.
- NFR-006: The first milestone must be small enough to debug independently.

## 9. Security and privacy
- Treat model output as untrusted input.
- Do not allow the model to run raw shell commands directly.
- Use allowlisted actions and argument validation.
- Require confirmation for file deletion, package installation, privileged operations, and data leaving the machine.
- Use a dedicated unprivileged process for the agent.
- Record action type, result, and timestamp in an audit log; avoid recording secrets or full sensitive content.
- Fail closed on errors.

## 10. Release acceptance checklist
- [ ] Build prerequisites documented.
- [ ] Profile preparation succeeds.
- [ ] Shell syntax checks pass.
- [ ] ISO build completes in an Arch VM.
- [ ] ISO boots in a disposable VM.
- [ ] Desktop, terminal, and networking verified.
- [ ] ISO checksum and package manifest recorded.
- [ ] No physical disk was modified.
- [ ] Known limitations documented.
