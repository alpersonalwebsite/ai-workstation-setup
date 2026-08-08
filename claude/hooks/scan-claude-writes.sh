#!/bin/bash
INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only watch authored config files inside ~/.claude/
# Skip auto-generated memory/runtime dirs: natural language content causes false positives
[[ -z "$FILE" || "$FILE" != *"/.claude/"* ]] && exit 0
[[ "$FILE" == *"/.claude/projects/"* ]] && exit 0
[[ "$FILE" == *"/.claude/sessions/"* ]] && exit 0
[[ "$FILE" == *"/.claude/cache/"* ]] && exit 0
[[ "$FILE" == *"/.claude/debug/"* ]] && exit 0

# Skip if file doesn't exist
[[ ! -f "$FILE" ]] && exit 0

if command -v gitleaks &>/dev/null; then
  if ! gitleaks detect --no-git --source "$FILE" 2>/dev/null; then
    echo "WARNING: Potential secret in Claude config/memory file: $FILE" >&2
    # change to exit 2 to block the write entirely
  fi
fi
exit 0
