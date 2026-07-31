---
name: fill-claude-md
description: Fill or update the CLAUDE.md in the current folder from its code, this session, and relevant memory, folder-scoped. Manual only.
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
