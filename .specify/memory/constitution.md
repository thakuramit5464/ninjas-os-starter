# Ninjas OS Constitution

## 1. Scripted, inspectable builds
Every OS customization must live in version-controlled configuration, scripts, package lists, or overlay files. A developer must be able to rebuild the image from a clean Arch VM by following the repository documentation.

## 2. Upstream-first Linux foundation
Use the official Arch Linux packages and Archiso `releng` profile unless a requirement clearly justifies a deviation. Keep customizations small and reviewable.

## 3. Safety before autonomy
The AI assistant is a user-space application, not a privileged system controller. It must use an explicit action allowlist, policy checks, least privilege, confirmations for sensitive operations, and audit logs. It must fail closed.

## 4. Human-readable operations
Build scripts must print what they are doing, validate prerequisites, stop on errors, and never silently modify a physical disk. Any destructive operation must require an explicit human action and clear target confirmation.

## 5. Incremental milestones
Deliver a bootable ISO first, then branding, then the AI controller, then desktop perception and controlled interaction. Do not combine unverified subsystems into one large change.

## 6. Testable claims
Never claim a build, VM boot, hardware test, or security property has passed unless it was actually tested. Clearly separate automated checks from manual validation.

## 7. Maintainability
Prefer supported system packages and documented configuration. Document upstream assumptions, package changes, recovery steps, and known limitations.

## 8. Privacy and local-first behavior
Prefer local inference where practical. Do not transmit screenshots, files, terminal output, or user activity to external services unless the user explicitly enables that provider and understands what is shared.

## 9. Release hygiene
Keep build outputs out of Git. Document the ISO version, build date, architecture, package manifest, and checksums for each release.
