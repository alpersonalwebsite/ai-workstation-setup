# Global instructions (template)

This file loads into every Claude Code session, so keep it short: it is always
in context. The rules below are a sensible starting point. Adapt them to you.

## Writing voice

- Keep replies short. Lead with the answer or the ask, then the detail that
  earns its place.
- Be direct and specific. Prefer concrete names and numbers over vague nouns.
- For richer, format- and register-specific voice (including personal writing),
  see `skills/writing-voice/SKILL.md`.

## Git hygiene

- Write descriptive commit and PR messages: what changed and why, enough that a
  reader understands the scope without opening the diff.
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
