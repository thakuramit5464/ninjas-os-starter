# Ninjas OS Spec Kit

A starter specification pack for building Ninjas OS: a fully scripted, Arch-based Linux distribution with a permission-controlled AI desktop assistant.

## Contents

- `CLAUDE.md` — instructions for Claude Code.
- `.specify/memory/constitution.md` — project principles and non-negotiable constraints.
- `specs/001-ninjas-os-foundation/spec.md` — product requirements and acceptance criteria.
- `specs/001-ninjas-os-foundation/plan.md` — implementation architecture and technical choices.
- `specs/001-ninjas-os-foundation/tasks.md` — implementation tasks.
- `prompts/claude-master-prompt.md` — copy/paste prompt for Claude Code.
- `prompts/speckit-workflow.md` — prompts for Specify, Plan, Tasks, and implementation.

## How to use

This pack has been extracted into the repository root (2026-10-16); `CLAUDE.md`, `.specify/`, `specs/` and `prompts/` live there now.

1. ~~Extract this pack into the root of your Ninjas OS repository.~~ Done.
2. Open that repository in Claude Code.
3. Read `CLAUDE.md` and `.specify/memory/constitution.md`.
4. Give Claude the prompt in `prompts/claude-master-prompt.md`.
5. Have Claude inspect the existing code before changing anything.
6. Implement one milestone at a time and run the available tests after each milestone.

If you use the official GitHub Spec Kit tooling, initialize it separately according to its current official instructions. These files are a Spec Kit-style project specification pack; they do not claim to install the upstream Spec Kit CLI.
