---
name: fact-check
description: Fact-check the claims in a diff, file, commit message, PR, report or conclusion before shipping or acting on it, numbers and data against the logs, metrics or database they came from, and API, config or CLI behavior against the real tool. Manual only.
disable-model-invocation: true
allowed-tools: Read Grep Glob
disallowed-tools: Write Edit
---

Fact-check the claims in a target before it ships or before acting on it.
Invoked manually at a high-stakes moment. The goal is to catch claims stated from
memory, or from a quick look, that were never actually checked against the real
source.

## Target

If a target was named (a file, a diff, a commit message, a PR, a report, a
specific claim), use it. Otherwise default to the uncommitted work plus any claims
just made: `git status --short`, `git diff HEAD` (staged and unstaged) and any
untracked files, since a plain `git diff` misses the last two. For a PR, read its
title, body and commits (`gh pr view`) and its diff (`gh pr diff`). State what is
being verified.

## What counts as a claim

- **Data:** counts, rates, percentages, sizes, durations, timestamps and dates,
  time windows, "X happened" or "X never happened", trends and comparisons, and
  anything said to be measured, verified or tested.
- **Behavior:** an API, runtime, library, config setting, CLI or system state.
- **Contents:** what a file, repo, table or dashboard contains or does not.

If there are too many to check, take the ones already written into something
durable (a comment, commit, PR, report) first, and say which you skipped.

## For each claim

1. Try to REFUTE it, not confirm it. Assume it is wrong until the evidence says
   otherwise.
2. Check it against the real source it came from: query the logs, metrics,
   database or API for a data claim; run the tool, read the source or `--help`,
   or fetch the official doc for a behavior claim. Prefer the direct source over
   a summary, a dashboard screenshot or the web.
3. For data, match the claim's conditions exactly and say them: an absolute time
   range with its timezone (not "the last 24h"), the same filters, the same
   units, and the same aggregation (count vs distinct, average vs p95, a count
   over a window vs a rate). Watch for sampling, retention limits, ingestion lag
   and a partial current window, any of which can make a correct query return a
   misleading number. Cross-check a key number a second way when that is cheap.
4. Read only. Never write, update, delete, restart, purge or re-run a job to
   test a claim. On production, prefer a read replica, a narrow time range and a
   `LIMIT`. Behavior that needs a side effect is tested only in a scratch copy,
   never against the real system, and never by pushing, deleting or messaging.
5. Ask for counts and aggregates, not raw rows: it keeps the output small, and it
   keeps personal data, secrets and customer records out of the report. Quote a
   row only when the claim is about that row, with sensitive fields redacted.
6. Show what was run and what came back: the query or command, the source, the
   time range, and the output. Record what it was checked against (tool version,
   commit, dataset or doc URL, and when), since the same check can answer
   differently later.
7. Ask what the evidence actually exercises. Shown output is not enough on its
   own: the question is whether the thing under test was real. Feeding invented
   inputs to a real system is evidence. A fixture, sample, mock, or stub standing
   in for the real system is not, and a test passing against one proves only
   that the code reads its own input. Where the only support for a claim about
   the outside world is an artifact built to illustrate it, that claim is
   UNVERIFIABLE, however green the test was.

## Report

Classify every claim checked, most consequential first:

- **VERIFIED**: with the query or command, the source and what it was checked
  against.
- **PARTLY TRUE**: what holds, what does not, and the exact correction (for
  example "6 of 8 copies, not every copy").
- **FALSE**: contradicted, with the evidence and the correction.
- **UNVERIFIABLE**: could not check with the access at hand, or the only
  evidence was something built to demonstrate the claim. Say so plainly, and say
  what access would settle it. Do not upgrade it to verified.

Then flag any claim already written into a durable artifact (comment, commit, PR,
report) that is not VERIFIED, since those do the real damage, and propose the
exact edit to fix or hedge each.

Do not pad. If every claim checks out, say so in one line.
