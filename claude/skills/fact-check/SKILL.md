---
name: fact-check
description: Fact-check the technical claims in a diff, file, commit message, or PR before shipping. Manual only.
disable-model-invocation: true
allowed-tools: Read Grep Glob
disallowed-tools: Write Edit
---

Fact-check the technical claims in a target before it ships. Invoked manually at
a high-stakes moment (before a commit, a PR, or acting on a conclusion). The goal
is to catch claims stated from memory that were never actually checked.

## Target

If a target was named (a file, a diff, a commit message, a PR body, a specific
claim), use it. Otherwise default to the current uncommitted diff plus any
technical assertions just made, and state what is being verified.

## For each claim

A claim is any statement about an API, runtime, framework, library, config
semantics, CLI behavior, or system state. For each one:

1. Try to REFUTE it, not confirm it. Assume it is wrong until the toolchain says
   otherwise.
2. Verify with the tools actually available: run the command, read the source or
   the installed package, check `--help`, fetch the official doc. Prefer the
   local toolchain over the web when the fact is checkable locally.
3. Show the command and its output.

## Report

Classify every claim, most consequential first:

- **VERIFIED**: with the command or output that backs it.
- **FALSE**: contradicted, with the evidence and the correction.
- **UNVERIFIABLE**: could not check with the tools at hand. Say so plainly. Do
  not upgrade it to verified.

Then flag any claim already written into a durable artifact (comment, commit, PR)
that is FALSE or UNVERIFIABLE, since those do the real damage, and propose the
exact edit to fix or hedge each.

Do not pad. If every claim checks out, say so in one line.
