#!/usr/bin/env bash
#
# statusline.sh: Claude Code custom status line (first-party, no network).
# Runs from ~/.claude/statusline.sh; enable it with the statusLine key in
# settings.json. Claude Code runs it every turn and pipes session JSON on stdin
# (https://code.claude.com/docs/en/statusline). It prints, with no third-party
# code and no outbound request:
#     <launcher>  [<model>]  ctx <N>%  $<session-cost>   ⎇ <git-branch>
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

# Which command started this session: plain `claude`, or a wrapper such as
# claude-extension (the second-account launcher in config/claude-proj.zsh),
# which runs the same binary under a different CLAUDE_CONFIG_DIR. A wrapper is a
# shell function, not a separate process, so there is nothing to read off the
# process tree or $0; each wrapper tags itself by setting CLAUDE_LAUNCHER on the
# claude command, and plain `claude` leaves it unset. This script is a child of
# the session process, so that environment is visible here (verified on build
# 2.1.222 and re-checked on 2.1.227: a session launched with CLAUDE_LAUNCHER set
# printed it from the status line).
#
# The tag is the precise mechanism, but it is a convention that has to be
# remembered, and forgetting it fails in the direction that looks correct: the
# bar reads `claude` for a session that is not one. So fall back to the config
# dir the session is on, which a second-account wrapper has to set anyway for
# reasons unrelated to this line. That labels the *config dir*, not the command,
# so two wrappers sharing one dir stay indistinguishable; the explicit tag is
# what separates those.
#
# Both signals come from the environment, which is undocumented ground: nothing
# promises Claude Code passes the session env to the statusLine command. If a
# future build sanitizes it, this degrades to printing `claude` for every
# session, which looks exactly like working correctly. If the label ever stops
# tracking the account, suspect that before suspecting the wrapper.
launcher=${CLAUDE_LAUNCHER:-}
if [ -z "$launcher" ]; then
  dir=${CLAUDE_CONFIG_DIR:-}
  case ${dir%/} in
    ''|"$HOME/.claude") launcher=claude ;;
    # The last guard is not redundant: a dir ending in `.` (`.`, `~/.`,
    # `~/.claude/.`, `./`) leaves nothing after the dot is stripped, and a blank
    # first field opens the bar with two spaces, which reads as a broken script
    # rather than a mislabeled session.
    *) launcher=${dir%/}; launcher=${launcher##*/}; launcher=${launcher#.}
       [ -n "$launcher" ] || launcher=claude ;;
  esac
fi

base=$(printf '%s  [%s]  ctx %s%%  $%.2f' "$launcher" "${model:-?}" "${pct:-0}" "${cost:-0}")

# Git branch when the working directory is a repo (cheap, local).
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -n "$branch" ] && base="$base  ⎇ $branch"

printf '%s\n' "$base"
