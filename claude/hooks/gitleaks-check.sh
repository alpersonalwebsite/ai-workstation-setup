#!/bin/bash
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path or lock files
[[ -z "$FILE" || "$FILE" == *.lock ]] && exit 0

# Skip if file doesn't exist (e.g. delete operations)
[[ ! -f "$FILE" ]] && exit 0

# Skip documentation and config files: natural language and pattern examples
# cause false positives. A commit-time secret scan, if you run one, covers these.
[[ "$FILE" == *.md ]] && exit 0
[[ "$FILE" == *.toml ]] && exit 0
[[ "$FILE" == *.gitleaks* ]] && exit 0

# PostToolUse runs after the write, so exit 2 cannot block it: it shows stderr
# to Claude, which is what a finding needs. --exit-code 3 keeps a finding apart
# from gitleaks' own errors, which exit 1 (measured 2026-11-02: a clean file with
# GITLEAKS_CONFIG pointing at a missing file exited 1, which this hook reported
# as "BLOCKED: gitleaks found potential secrets"). Findings are read from
# gitleaks' verbose output, which goes to stdout (stderr carries only log lines)
# with the secret replaced by REDACTED; both are captured, and only the RuleID
# and Line fields are kept. Needs gitleaks 8.16.2 or later for --no-color
# (--no-banner arrived in 8.13.0); an older one fails every scan, loudly.
# --follow-symlinks: without it gitleaks skips a file that is itself a symlink
# and exits 0, so the write read as clean unscanned (measured 2026-11-02 with
# 8.27.2: rc 0 without, rc 3 with). Config files here are often symlinks, such
# as a stowed CLAUDE.md or settings.json. The flag is on detect since 8.15.0.
# Deliberate fail-open: with no gitleaks installed the hook exits 0 and the
# write goes unscanned, with no warning. A warning here would fire on every
# write on a machine without gitleaks; the setup docs list gitleaks as a
# requirement instead. Reviewed and kept 2026-11-02.
if command -v gitleaks &>/dev/null; then
  if OUT=$(gitleaks detect --no-git --follow-symlinks --redact -v --no-banner --no-color --exit-code 3 --source "$FILE" 2>&1); then
    exit 0
  else
    RC=$?
  fi
  if [[ $RC -eq 3 ]]; then
    WHERE=$(printf '%s\n' "$OUT" | awk '$1 == "RuleID:" {r = $2} $1 == "Line:" {printf "%s%s at line %s", sep, r, $2; sep = ", "}')
    echo "WARNING: gitleaks found a potential secret in $FILE (${WHERE:-rule and line not reported}). The write already happened. Tell the user the file and line, never the value, and ask before changing it." >&2
  else
    echo "WARNING: gitleaks failed (exit $RC) on $FILE, so it was not scanned for secrets." >&2
  fi
  exit 2
fi
exit 0
