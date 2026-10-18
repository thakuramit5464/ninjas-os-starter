# Ninjas OS AI controller - architecture (design only, not implemented)

This document fixes the design constraints for the AI assistant that later
milestones (Phase 4 in `specs/001-ninjas-os-foundation/tasks.md`) will
implement. Nothing here ships in Alpha 0.1. The ISO build pipeline must be
validated first.

## Non-negotiables (from the constitution and CLAUDE.md)

1. The model never executes arbitrary shell strings. There is no
   `run_shell(command)` action and never will be.
2. The model never has root. The agent runs as the desktop user (or a
   dedicated less-privileged user) with no sudo rule.
3. Deny by default. Any action not in the allowlist, or with arguments that
   fail validation, is rejected before anything runs.
4. Confirmation for sensitive actions (delete, install, privileged, network
   egress, reading private data) happens in a UI the model cannot drive.
5. Timeouts, resource limits, and an audit log on every executed action. The
   log never stores secrets or full sensitive content.
6. Fail closed: any error in parsing, validation, or policy evaluation ends in
   "denied", not "allowed".
7. Local-first: a local model provider is the default; remote providers are
   opt-in per provider and clearly disclose what leaves the machine.
8. Off by default: the agent is a normal user service that the user starts
   explicitly; it is not enabled in the image.

## Components

```
 user ──► ninjas-ui (Qt/QML or CLI)
              │  natural language
              ▼
        ninjas-agent (Python, unprivileged, systemd --user service)
          ├─ provider/      LLM adapters: local (llama.cpp/Ollama-style HTTP), remote (opt-in)
          ├─ planner        prompt + tool schema → model → JSON actions
          ├─ schema/        typed actions (pydantic), strict parsing, unknown fields rejected
          ├─ policy/        allowlist, argument validators, risk classes, confirmation rules
          ├─ executor/      one narrow function per action, subprocess with argv lists, timeouts
          ├─ perception/    explicitly permitted state readers (window list, battery, etc.)
          └─ audit/         append-only JSONL log, redaction, rotation
```

Trust boundary: everything the model produces (text or JSON) is untrusted
input, as is everything read from the screen, files, or web. Prompt injection
in a document the agent reads must not be able to widen permissions; policy
evaluation never consults model output for *whether* something is allowed,
only for *what* is requested.

## Action schema (sketch)

Actions are typed records, not strings. Example set for the first increment:

| Action | Arguments | Risk class | Executor |
| --- | --- | --- | --- |
| `open_app` | `app_id` from the installed `.desktop` set | low | `gio launch` / `kioclient` with validated id |
| `open_url` | `url` (http/https only, parsed, no credentials) | low-medium | `xdg-open` |
| `list_directory` | `path` under an allowlisted root, no symlink escape | low | Python `os.scandir` |
| `read_text_file` | `path` (same rules), max bytes | medium (privacy) | Python, size-capped |
| `read_system_status` | none | low | `systemctl --failed`, `nmcli`, battery via D-Bus |
| `set_volume` | `percent` 0-100 | low | `wpctl` |
| `move_to_trash` | `path` (same rules) | **high, confirm** | `gio trash` |
| `install_package` | `name` matching `^[a-z0-9@._+-]+$` and present in repos | **high, confirm, privileged via polkit-gated helper** | later milestone |

Rules:

- Each action has a pydantic model with `extra="forbid"`. Unknown action
  names or fields are rejected.
- Paths are canonicalised (`realpath`) and must stay inside the configured
  roots (`~/Documents`, `~/Downloads`, ... by default). `..`, symlinks that
  escape, and hidden `.ssh`/`.gnupg`-style directories are denied.
- Subprocesses are invoked with argument lists, never `shell=True`, with a
  minimal environment, a timeout (default 10 s), and output size caps.
- Privileged operations (package install, service control) are not run by the
  agent at all. If ever needed, they go through a separate, tiny, audited
  helper with its own polkit policy and an argument contract, never via sudo.

## Policy engine

```
decide(action) -> Allow | AskUser(reason) | Deny(reason)
```

- Allowlist keyed by action name; a per-action validator runs on the parsed
  arguments; a risk class maps to `Allow` or `AskUser`.
- User-configurable *tightening* only (e.g. remove `open_url`); loosening
  requires editing a root-owned policy file.
- Rate limiting (actions per minute) and a global "pause the agent" switch.
- All `Deny` decisions are logged with the action name and reason, with
  arguments redacted to a hash + length.

## Audit log

JSON lines in `~/.local/state/ninjas-agent/audit.jsonl` (0600), one record per
decision: timestamp, action name, decision, confirmation outcome, exit status,
duration, truncated/hashed arguments. Never: file contents, screenshots,
tokens, environment variables, full URLs with query strings.

## Tests required before any action executes on a real desktop

- Schema: unknown action, extra field, wrong type, oversize string → rejected.
- Policy: path traversal (`../`, symlink escape, `~/.ssh`), URL with
  credentials or `file:` scheme, package names with shell metacharacters → denied.
- Confirmation: high-risk actions never execute without an explicit `confirmed`
  token issued by the UI, and that token is single-use.
- Executor: timeouts fire; `shell=True` is absent (grep-based test);
  environment is minimal.
- Audit: a deny and an allow are both logged; secrets in arguments are
  redacted.

## Packaging in the image (later)

- Python package `ninjas-agent` installed under `/usr/lib/ninjas-agent` with
  its own venv or as a pacman package built from this repo.
- `systemd --user` unit, **not enabled**; a desktop launcher starts it.
- Local model weights are not shipped in the ISO (size); the provider points
  at a user-installed local server by default and reports "no model available"
  otherwise.
