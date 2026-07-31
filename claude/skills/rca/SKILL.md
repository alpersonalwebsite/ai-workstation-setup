---
name: rca
description: Draft an incident root-cause analysis in the finding / evidence / fix format. Gathers the signal, separates measured from inferred, states the prior behavior, and proposes the fix and follow-ups. Manual only.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob
---

Draft a root-cause analysis for an incident. Invoked manually with `/rca`. Match
the finding / evidence / fix shape the `writing-voice` skill describes. The goal
is a writeup someone can act on and trust, not a story.

## Gather first

If I named the incident, use it. Otherwise ask what broke and when, then pull
what you can: logs, metrics, recent deploys or changes, `git log` around the
window, config diffs, alerts. Show the signal rather than describe it.

## Structure

1. **Summary**: one or two lines, what broke, blast radius, when, current status.
2. **Timeline**: key moments (first symptom, detection, mitigation, resolution)
   with absolute timestamps.
3. **What happened**: the failure path, concrete and specific ("431s on all
   chunked POSTs", not "an error").
4. **Root cause**: the actual cause, not the trigger. State the prior behavior it
   changed from; a change that narrowed working input is a regression, name it.
5. **Fix**: what resolves it, and what is verified versus still open.
6. **Follow-ups**: prevention, monitoring, the checklist items.

## Rules

- Separate **measured** (backed by a log line, metric, or command output you
  show) from **inferred** (reasoning). Label inference as inference; never present
  it as fact.
- No unverified claims in the writeup. If you cannot confirm something, say so.
- Watch disclosure: an RCA names hosts, clients, and incident detail. Keep those
  out of anything committed to a shared repo; they belong in the private writeup.
- Be specific and brief. No em dashes.

Show the draft. Write it to a file only if I ask.
