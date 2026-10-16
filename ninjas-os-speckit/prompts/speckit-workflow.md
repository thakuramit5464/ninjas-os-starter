# Spec Kit Workflow Prompts

These prompts can be used with Claude Code or adapted to the official GitHub Spec Kit workflow.

## 1. Specify
Read the project context and write a clear feature specification for the Ninjas OS Alpha foundation. Include user stories, measurable acceptance criteria, functional and non-functional requirements, security constraints, privacy requirements, and explicit non-goals. Keep the first release to a scripted Archiso live ISO and do not silently include the AI agent as a completed feature. Save/update `specs/001-ninjas-os-foundation/spec.md`. Identify unresolved assumptions instead of inventing facts.

## 2. Plan
Using the constitution and approved specification, create a technical implementation plan for an Archiso `releng`-based build. Define profile preparation, package list overlays, filesystem overlays, build output locations, VM testing, and failure recovery. Account for Arch rolling-release behavior and do not claim bit-for-bit reproducibility without pinned package sources. Save/update `specs/001-ninjas-os-foundation/plan.md`.

## 3. Tasks
Convert the approved plan into small, ordered, independently verifiable tasks. Each task should identify concrete files or components and a test/validation step. Separate static checks, build checks, VM smoke tests, and later AI safety work. Save/update `specs/001-ninjas-os-foundation/tasks.md`.

## 4. Implement
Implement only the next unchecked task group. First inspect the repository and current Archiso profile; then make a minimal diff, run applicable tests, update the task checklist, and report exact test outcomes. Do not claim tests passed unless they were run. Do not write an ISO to a physical disk.

## 5. Review
Review the current diff as a senior Linux distribution engineer. Look for destructive filesystem operations, unsafe shell quoting, assumptions about Archiso profile layout, broken service enablement, missing package dependencies, insecure sudo/autologin configuration, and claims unsupported by tests. Fix confirmed issues and explain remaining risks.

## 6. AI safety review
Review the proposed AI desktop controller for prompt injection, arbitrary shell execution, path traversal, privilege escalation, unintended network calls, unsafe deletion, and leaking sensitive content into logs. Require typed actions, deny-by-default policy, least privilege, confirmations for sensitive actions, timeouts, and tests. Reject any design that lets the model bypass the policy engine.
