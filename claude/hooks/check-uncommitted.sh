#!/bin/bash
# Stop hook: warn at session end if the working tree has uncommitted changes.
# Warn-only: never blocks the stop. Silent when clean, when cwd is not a git
# repo, or when the repo root cannot be resolved (e.g. corrupted repo, perms).

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

[[ -z "$CWD" ]] && exit 0

# Skip if not a git repo
git -C "$CWD" rev-parse --git-dir &>/dev/null || exit 0

# Resolve to the repo root so the warning names the repository, not the
# session's subdirectory (e.g. ".../foo/src" still reports as "foo").
REPO_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0
REPO_NAME=$(basename "$REPO_ROOT")

STATUS=$(git -C "$CWD" status --porcelain 2>/dev/null)
[[ -z "$STATUS" ]] && exit 0

TOTAL=$(echo "$STATUS" | wc -l | tr -d ' ')
UNTRACKED=$(echo "$STATUS" | grep -cE '^\?\?' || true)
TRACKED=$((TOTAL - UNTRACKED))

PARTS=()
[[ $TRACKED -gt 0 ]] && PARTS+=("$TRACKED modified")
[[ $UNTRACKED -gt 0 ]] && PARTS+=("$UNTRACKED untracked")

JOINED=$(printf "%s, " "${PARTS[@]}")
JOINED=${JOINED%, }
echo "UNCOMMITTED CHANGES in $REPO_NAME: $JOINED" >&2
exit 0
