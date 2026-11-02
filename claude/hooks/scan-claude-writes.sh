#!/bin/bash
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only watch files inside the Claude config dir: any path containing /.claude/
# (~/.claude/ and the dotfiles copy it links to), plus $CLAUDE_CONFIG_DIR when
# Claude Code runs from another directory such as ~/.claude-extension, whose
# paths never contain /.claude/.
REL=""
if [[ -n "$CLAUDE_CONFIG_DIR" && "$FILE" == "${CLAUDE_CONFIG_DIR%/}/"* ]]; then
  REL="${FILE#"${CLAUDE_CONFIG_DIR%/}/"}"
elif [[ "$FILE" == *"/.claude/"* ]]; then
  REL="${FILE#*/.claude/}"
fi
[[ -z "$REL" ]] && exit 0

# Skip runtime dirs: transcripts and caches are natural language and cause false
# positives. Memory files are the exception: they persist across sessions and are
# where a pasted credential ends up, and no other hook scans them
# (gitleaks-check.sh skips *.md). Measured 2026-11-02: across 864 memory files,
# gitleaks flagged one real credential (in two copies) and nothing else.
case "$REL" in
  projects/*/memory/*) ;;
  projects/*|sessions/*|cache/*|debug/*) exit 0 ;;
esac

# Skip if file doesn't exist
[[ ! -f "$FILE" ]] && exit 0

# Exit 2 is how a PostToolUse hook gets a warning seen: Claude Code shows its
# stderr to Claude, while the stderr of a hook that exits 0 reaches only the debug
# log ("Claude never sees stderr from a hook that exits 0", code.claude.com/docs/en/hooks,
# read 2026-11-02). Until then this hook printed and exited 0, so no warning was
# ever seen. The write has already happened: PostToolUse cannot undo or block it.
#
# --exit-code 3 keeps a finding apart from gitleaks' own errors, which exit 1
# (measured 2026-11-02: a clean file with GITLEAKS_CONFIG pointing at a missing
# file exited 1, which this hook used to report as a secret). An error is reported
# as a failed scan, not as a finding. Findings are read from gitleaks' verbose
# output, which goes to stderr with the secret replaced by REDACTED; only the
# RuleID and Line fields are kept from it.
if command -v gitleaks &>/dev/null; then
  if OUT=$(gitleaks detect --no-git --redact -v --no-banner --no-color --exit-code 3 --source "$FILE" 2>&1); then
    exit 0
  else
    RC=$?
  fi
  if [[ $RC -eq 3 ]]; then
    WHERE=$(printf '%s\n' "$OUT" | awk '$1 == "RuleID:" {r = $2} $1 == "Line:" {printf "%s%s at line %s", sep, r, $2; sep = ", "}')
    echo "WARNING: gitleaks flagged a potential secret in Claude config/memory file $FILE (${WHERE:-rule and line not reported}). The write already happened. Tell the user the file and line, never the value, and ask before changing it." >&2
  else
    echo "WARNING: gitleaks failed (exit $RC) on Claude config/memory file $FILE, so it was not scanned for secrets." >&2
  fi
  exit 2
fi
exit 0
