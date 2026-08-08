#!/bin/bash
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

[[ -z "$CWD" ]] && exit 0

WARNINGS=()

[[ ! -f "$CWD/.gitignore" ]] && WARNINGS+=("No .gitignore found")

if [[ -f "$CWD/.gitignore" ]]; then
  # Strip comment and blank lines so a comment mentioning a pattern (e.g.
  # `# .env files`) does not falsely satisfy the check for that pattern.
  patterns=$(grep -vE '^[[:space:]]*(#|$)' "$CWD/.gitignore")

  ! echo "$patterns" | grep -qE '\.env'         && WARNINGS+=(".env* not in .gitignore")
  ! echo "$patterns" | grep -qE '\.log($|/)'    && WARNINGS+=("*.log not in .gitignore")
  ! echo "$patterns" | grep -qE '\.pem($|/)'    && WARNINGS+=("*.pem not in .gitignore")
  ! echo "$patterns" | grep -qE '\.key($|/)'    && WARNINGS+=("*.key not in .gitignore")
  ! echo "$patterns" | grep -qE 'secrets'       && WARNINGS+=("secrets/ not in .gitignore")
  ! echo "$patterns" | grep -qE 'credentials'   && WARNINGS+=("credentials* not in .gitignore")
  ! echo "$patterns" | grep -qE 'node_modules'  && WARNINGS+=("node_modules/ not in .gitignore")
  ! echo "$patterns" | grep -qE '__pycache__'   && WARNINGS+=("__pycache__/ not in .gitignore")
  ! echo "$patterns" | grep -qE '\.DS_Store'    && WARNINGS+=(".DS_Store not in .gitignore")
  ! echo "$patterns" | grep -qE '\.sqlite($|/)' && WARNINGS+=("*.sqlite not in .gitignore")
  ! echo "$patterns" | grep -qE '\.db($|/)'     && WARNINGS+=("*.db not in .gitignore")
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo "SECURITY WARNING: ${WARNINGS[*]}" >&2
fi
exit 0
