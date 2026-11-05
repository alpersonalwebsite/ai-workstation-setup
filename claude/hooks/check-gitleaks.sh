#!/bin/bash
# SessionStart: say at the start of each session that gitleaks is missing.
#
# gitleaks-check.sh and scan-claude-writes.sh fail open without gitleaks: every
# write goes unscanned with no warning, deliberately, since a warning there would
# fire on every write. This hook is the one place that says so. It prints nothing
# when gitleaks is installed, and always exits 0: SessionStart cannot block, and a
# missing scanner is a reason to warn, not to stop the session. It repeats on a
# resume, since SessionStart fires there too (measured 2026-11-04: source
# "startup", then "resume", with the matcher empty).
#
# THIS FILE SHIPS UNCHANGED to the ai-workstation-setup template, so what differs
# between machines is decided here at run time rather than by keeping two copies:
#   - The commit-time fallback is mentioned only when the global pre-commit hook
#     actually carries one, recognised by its SECRET_PATTERN= line. Any pre-commit
#     hook without that line is not taken for it, and a machine with none at all
#     (the template's own setup) is told only about the write-time scans.
#   - The fix is `brew install gitleaks` where brew exists, the install page
#     otherwise.
#
# OUTPUT: one JSON object, with systemMessage (shown to the user, as
# "SessionStart:startup says: ...") and additionalContext (seen by Claude). Both
# measured 2026-11-04 on Claude Code 2.1.311. Without jq the same text goes out as
# plain stdout, which SessionStart adds to Claude's context, so it is never lost.

cat >/dev/null

command -v gitleaks >/dev/null 2>&1 && exit 0

hooks_dir=
if command -v git >/dev/null 2>&1; then
  hooks_dir=$(git config --global --type=path core.hooksPath 2>/dev/null)
  # git resolves a relative core.hooksPath against the repo root, not the cwd
  # (measured 2026-11-04, git 2.39.5: a commit from a subfolder ran the root's
  # .githooks/pre-commit), so resolve it there too. Against the cwd, a session
  # started in a subfolder missed the fallback.
  if [[ -n "$hooks_dir" && "$hooks_dir" != /* ]]; then
    top=$(git rev-parse --show-toplevel 2>/dev/null) && hooks_dir="$top/$hooks_dir"
  fi
fi
[[ -n "$hooks_dir" ]] || hooks_dir="$HOME/.git-hooks"

msg="gitleaks is not installed, so Claude Code's write-time secret scans (gitleaks-check.sh, scan-claude-writes.sh) are skipped on this machine"
if [[ -f "$hooks_dir/pre-commit" ]] && grep -q '^SECRET_PATTERN=' "$hooks_dir/pre-commit" 2>/dev/null; then
  msg="$msg, and commits get only the pre-commit fallback pattern scan"
fi
if command -v brew >/dev/null 2>&1; then
  msg="$msg. Fix: brew install gitleaks"
else
  msg="$msg. Fix: install gitleaks, see https://github.com/gitleaks/gitleaks#installing"
fi

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg m "$msg" \
    '{systemMessage:$m, hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:$m}}'
else
  printf '%s\n' "$msg"
fi
exit 0
