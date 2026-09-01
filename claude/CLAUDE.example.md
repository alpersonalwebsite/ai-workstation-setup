# Global instructions (template)

This file loads into every Claude Code session, so keep it short: it is always
in context. The rules below are a sensible starting point. Adapt them to you.

## Writing voice

- Keep replies short. Lead with the answer or the ask, then the detail that
  earns its place.
- Be direct and specific. Prefer concrete names and numbers over vague nouns.
- For richer, format- and register-specific voice (including personal writing),
  see `skills/writing-voice/SKILL.md`.

## Verification

- A technical claim (API, runtime, framework, config semantics, system state)
  that goes into a durable artifact (code comment, commit message, PR, or a
  conclusion you act on) must be either backed by tool output shown in the
  session, or labeled "unverified, from memory." No unlabeled claims from memory.
- When hardening or fixing something, measure before and after and state what the
  prior behavior actually was. "Hardening" that narrows working input is a
  regression.
- Brevity never drops verification status. Keep measured separate from inferred,
  even when summarizing.
- Self-authored inputs are fine; self-authored stand-ins are not. The test is
  whether the thing under test is real, not whether you chose the input. Probing a
  real library or system with values you invented is evidence. A fixture standing
  in for the real system is not, and a test passing against it proves only that the
  code reads your own file. When a claim about the outside world rests on an
  artifact you built to illustrate it, treat it as unverified: find a real instance,
  or say plainly that none was found.
- For a deliberate pre-ship check of a claim-heavy artifact, run the
  `/fact-check` skill (see `skills/fact-check/SKILL.md`).

## Git hygiene

- Write descriptive commit and PR messages: what changed and why, enough that a
  reader understands the scope without opening the diff. When several files
  change, say what changed in each, or group them by change.
- On shared repositories, branch and open a PR rather than committing straight
  to the main branch.
- Decide your own policy on AI-assistance attribution in commit messages, and be
  consistent about it.

## Security

- Never write secrets, API keys, or tokens into source files.
- Scaffold a `.gitignore` before the first commit; make sure it covers env
  files, keys, logs, local databases, and OS or editor cruft.
- Flag hardcoded credentials when you see them instead of moving past them.

## Memory

- Do not persist secrets or personal data (keys, tokens, passwords, PII) to any
  memory or notes file.
