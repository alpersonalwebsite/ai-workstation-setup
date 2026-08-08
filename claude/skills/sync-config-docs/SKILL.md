---
name: sync-config-docs
description: Check for drift between the live ~/.claude/ config and the docs that describe it. Fill in the two paths below before using.
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, Bash
---

Audit drift between the live Claude Code config and whatever documents it.

**Fill these in before using this skill.** They are the only project-specific part,
and the skill is useless until they point somewhere real:

- **Config lives at:** `[e.g. ~/dotfiles/claude/.claude/, the authored files that
  are symlinked into ~/.claude/. If you do not use a dotfiles repo, this is just
  ~/.claude/]`
- **Docs live at:** `[e.g. ~/notes/claude-config/, or a docs/ folder inside the
  same repo. Wherever you describe the config in prose]`

If you keep no separate documentation, this skill has nothing to compare and you
should not install it.

## Steps

1. Enumerate every authored file under the config path, by category rather than by
   listing filenames, so new files inside a known category are caught:
   - `CLAUDE.md`
   - `settings.json`
   - `statusline.sh`, and any other top-level scripts
   - every file under `hooks/`
   - every `SKILL.md` under `skills/<name>/`
   - every `.md` under `agents/`
   - any other top-level config file that exists there

   A brand-new *category* still has to be added to this list by hand. That is a
   real limitation, not an oversight: the enumeration cannot know about a directory
   nobody has told it about, and a category added silently is exactly the drift
   this skill is meant to catch.

2. For each authored file, locate its documentation:
   - find docs that reference the file by name or path
   - find code blocks in docs that quote the file's content

3. Report findings in three categories:

   **Content drift**: the file differs from what the docs quote. Show the file
   path, the doc path, and the diff.

   **Missing documentation**: the file exists but no doc references it. Suggest
   where to add it, extending an existing doc or creating one and linking it from
   the docs index.

   **Orphaned documentation**: docs reference files that no longer exist. Suggest
   removal or correction.

4. Group by severity: content drift first, then missing docs, then orphaned docs.
   Give a specific remediation step for each.

5. If everything is in sync, say so plainly. No false positives, no padding.

## Notes

- Compare semantically where formatting differs harmlessly. Extra blank lines
  inside a quoted code block are not drift.
- Expect near-mirrors that are deliberately not identical. Where a doc paraphrases
  a rule rather than quoting it, or a public copy is reworded from a private one,
  that is intended and should not be reported as drift. Say which pairs those are
  when you find them, so the next run does not re-flag them.
