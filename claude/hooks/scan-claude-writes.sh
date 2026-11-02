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
if command -v gitleaks &>/dev/null; then
  if ! gitleaks detect --no-git --redact --source "$FILE" >/dev/null 2>&1; then
    echo "WARNING: gitleaks flagged a potential secret in Claude config/memory file $FILE. The write already happened. Tell the user the file and line, never the value, and ask before changing it." >&2
    exit 2
  fi
fi
exit 0
