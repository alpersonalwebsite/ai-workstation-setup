#!/usr/bin/env bash
#
# statusline.sh: Claude Code custom status line (first-party, no network).
# Copy to ~/.claude/statusline.sh, chmod +x, and set the statusLine key in
# settings.json. Claude Code runs it every turn and pipes session JSON on stdin
# (https://code.claude.com/docs/en/statusline). It prints, with no third-party
# code and no outbound request:
#     [<model>]  ctx <N>%  $<session-cost>   ⎇ <git-branch>
# Fields used:
#   .model.display_name
#   .context_window.used_percentage   (null early in a session / after /compact)
#   .cost.total_cost_usd              (list-rate estimate, resets on /clear)
# Only dependency is jq.

input=$(cat)

# Pull the fields as TSV so a multi-word model name ("Opus 4.8") stays intact
# (IFS=tab), then format cost in the shell. jq has no fixed-decimal float
# formatting, so a raw number renders at a varying width ($0.5, $1, $0.56) on a
# line that redraws every turn; printf %.2f keeps it steady.
IFS=$'\t' read -r model pct cost <<<"$(printf '%s' "$input" | jq -r '
  [ (.model.display_name // "?"),
    ((.context_window.used_percentage // 0) | floor),
    (.cost.total_cost_usd // 0)
  ] | @tsv')"

base=$(printf '[%s]  ctx %s%%  $%.2f' "${model:-?}" "${pct:-0}" "${cost:-0}")

# Git branch when the working directory is a repo (cheap, local).
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -n "$branch" ] && base="$base  ⎇ $branch"

printf '%s\n' "$base"
