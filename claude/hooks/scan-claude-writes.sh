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

if command -v gitleaks &>/dev/null; then
  if ! gitleaks detect --no-git --source "$FILE" 2>/dev/null; then
    echo "WARNING: Potential secret in Claude config/memory file: $FILE" >&2
    # change to exit 2 to block the write entirely
  fi
fi
exit 0
