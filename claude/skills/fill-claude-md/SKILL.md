---
name: fill-claude-md
description: Fill or update the CLAUDE.md in the current folder from its code, this session, and relevant memory, folder-scoped, or AGENTS.md plus a one-line CLAUDE.md import when other coding agents work there too. Manual only.
disable-model-invocation: true
allowed-tools: Read Grep Glob
---

Fill or update the CLAUDE.md in the CURRENT folder (the working directory,
whether it is the repo root or a subfolder). Invoked manually with
`/fill-claude-md`. Pick the mode by the folder's state:

- **Fresh or existing folder:** populate the `initclaude` template (or a sparse
  CLAUDE.md) from scratch.
- **Ongoing project:** at the end of a session, fold in what changed ("update
  CLAUDE.md with what we did and decided"). It builds up as you work.

## Scope: this folder, not the repo

Write the CLAUDE.md that belongs to THIS folder. Do not move it to the repo root.
Describe this folder: base it on this folder's code and docs, this session, and
relevant memory. You may pull context from parent or sibling folders where it
helps explain this folder, but keep the file about this folder, not the whole
repo. Claude Code loads CLAUDE.md by directory, so a subfolder file stacks on the
repo root's only when you launch in that subfolder.

## CLAUDE.md or AGENTS.md

`AGENTS.md` is the shared instructions file other coding agents read (Codex,
Cursor, Copilot and more). Below, "`CLAUDE.md`" means this folder's `CLAUDE.md`
or `.claude/CLAUDE.md`, and "`AGENTS.md`" means its `AGENTS.md` or
`.claude/AGENTS.md`, whichever exists: update that one, never add a second.
"The import" (`@AGENTS.md` below) is the path from the `CLAUDE.md` file to the
`AGENTS.md` file, because an `@` import resolves relative to the file that
contains it, not the folder: `@AGENTS.md` from `./CLAUDE.md`, but
`@../AGENTS.md` from `.claude/CLAUDE.md`. Written as a bare `@AGENTS.md` inside
`.claude/CLAUDE.md`, it points at `.claude/AGENTS.md` and loads nothing when the
file is at the root. Pick the file by what the folder already has:

- **Neither file yet:** ask once, before drafting: will agents other than Claude
  work in this folder? **No:** write `CLAUDE.md`, as below. **Yes:** write the
  instructions to `AGENTS.md`, and make `CLAUDE.md` a single `@AGENTS.md` line,
  plus any notes that only apply to Claude, so every agent reads one source.
- **Only `AGENTS.md`:** update it, and add a one-line `CLAUDE.md` containing
  `@AGENTS.md` rather than a second copy of the content.
- **Both, and `CLAUDE.md` already imports `@AGENTS.md`:** update `AGENTS.md`;
  touch `CLAUDE.md` only for Claude-only notes.
- **Both, and no import:** add the `@AGENTS.md` line to `CLAUDE.md`, and move any
  content that appears in both out of `CLAUDE.md` so `AGENTS.md` is the one
  source. Without this step, an update to `AGENTS.md` is never read by Claude.
- **Only `CLAUDE.md`:** update it, and do not ask; offer `AGENTS.md` only if the
  user says another agent is coming.

The import is not optional when both files exist: with a `CLAUDE.md` present,
Claude Code reads only `CLAUDE.md` by default and skips `AGENTS.md`, so a
`CLAUDE.md` without `@AGENTS.md` silently hides the shared file from Claude. The
import never loads it twice. A `CLAUDE.local.md` (personal, uncommitted) counts
too: with one present Claude also skips `AGENTS.md` unless a `CLAUDE.md` imports
it, so it is one more reason the import has to exist. Never write project
instructions into `CLAUDE.local.md`.

Everything below applies to whichever file holds the instructions.

## Sources, in order of authority

1. **The folder's code and docs** are ground truth.
2. **This session** and **relevant memory** carry recent decisions and half-done
   state not yet in the code. On a true cold start (a folder never opened with
   Claude), the code is the only source with anything in it.

## Guardrails

- Do not invent. Verify counts and IDs against the files rather than estimating,
  and mark anything you cannot confirm as unverified.
- Show the diff before writing, and do not write until it is approved.

## After writing, skim for two things

- **Accuracy:** does it match the code and the decisions actually made?
- **Disclosure:** the file is committed with the folder, but the session and
  memory can hold what the repo should not (client names, incident detail,
  internal hostnames, pasted secrets). Keep those out of the committed file. A
  wrong or oversharing CLAUDE.md is worse than a blank one, since it is trusted
  every session.

To confirm the file loads, run `/context` and check the list under Memory files.
