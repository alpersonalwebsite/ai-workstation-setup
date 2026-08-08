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

if command -v gitleaks &>/dev/null; then
  if ! gitleaks detect --no-git --source "$FILE" 2>/dev/null; then
    echo "BLOCKED: gitleaks found potential secrets in $FILE" >&2
    exit 2
  fi
fi
exit 0
