# ~/.claude-proj.zsh
# Claude Code project switcher + CLAUDE.md scaffold.
# Installed to ~/.claude-proj.zsh by setup.sh and sourced from ~/.zshrc.
# Canonical source: alpersonalwebsite/ai-workstation-setup, config/claude-proj.zsh
#
#   proj        no args: fuzzy-pick a project Claude has already opened and
#               attach its tmux session. With a path (`proj .`, `proj <dir>`):
#               attach/create a session for that folder, works for brand-new
#               projects too. Session name is deterministic, so proj always
#               reattaches the same session rather than spawning duplicates.
#   initclaude  scaffold a CLAUDE.md (project memory) in the current folder.

# List Claude Code's known project dirs, deduped. Order follows $PROJ_SORT:
#   recent (default) = most-recently-active first
#   alpha            = alphabetical by path (case-insensitive)
# Paths are read from each session's recorded `cwd` (accurate even when the
# folder name contains hyphens, which the on-disk encoding mangles).
_claude_projects() {
  emulate -L zsh
  local d cwd m
  local -a files
  {
    for d in ~/.claude/projects/*/(N); do
      files=( "$d"*.jsonl(Nom) )   # N=nullglob, om=newest-first by mtime
      (( ${#files} )) || continue
      cwd=$(grep -ao '"cwd":"[^"]*"' "${files[1]}" 2>/dev/null | head -1 | sed 's/.*"cwd":"//; s/".*//')
      [[ -n "$cwd" && -d "$cwd" ]] || continue
      m=$(stat -f '%m' "${files[1]}" 2>/dev/null)
      printf '%s\t%s\n' "$m" "$cwd"
    done
  } | if [[ "${PROJ_SORT:-recent}" == "alpha" ]]; then
        cut -f2- | sort -f
      else
        sort -rn | cut -f2-
      fi | awk '!seen[$0]++'
}

# Attach or create a project's tmux session.
#   proj        fuzzy-pick from projects Claude has already opened
#   proj .      use the current directory (or `proj <path>`) — works for NEW folders
proj() {
  emulate -L zsh
  local dir sess hash
  (( $# <= 1 )) || { print -u2 "usage: proj [directory]"; return 2; }
  if [[ -n "$1" ]]; then
    dir=${1:A}                    # absolute path; handles `proj .` and new folders
    [[ -d "$dir" ]] || { print -u2 "proj: no such directory: $1"; return 1; }
  else
    # No quotes around {}: fzf already substitutes it as a shell-quoted string,
    # so "{}/CLAUDE.md" would look for a literally-quoted path and never match.
    dir=$(_claude_projects | fzf \
          --prompt='project ▸ ' --reverse --height=60% \
          --preview 'test -f {}/CLAUDE.md && cat {}/CLAUDE.md || echo "(no CLAUDE.md yet — run: initclaude)"' \
          --preview-window=right:55%:wrap) || return
    [[ -n "$dir" ]] || return
  fi
  # Session name: readable basename plus a short hash of the FULL path, so
  # ~/src/api and ~/work/api (and foo-bar vs foo_bar, which sanitize to the
  # same string) get distinct sessions instead of silently sharing one.
  hash=$(printf '%s' "$dir" | cksum | cut -d' ' -f1)
  sess=${dir:t}                 # basename
  sess=${sess//[^[:alnum:]_]/_} # tmux-safe name
  sess="${sess}_${hash}"
  tmux has-session -t "$sess" 2>/dev/null || tmux new-session -d -s "$sess" -c "$dir"
  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$sess"
  else
    tmux attach -t "$sess"
  fi
}

# Scaffold a CLAUDE.md (project memory) in the current directory.
initclaude() {
  emulate -L zsh
  local target="${1:-CLAUDE.md}"
  if [[ -e "$target" ]]; then
    print -u2 "❌ $target already exists — not overwriting."
    return 1
  fi
  # Guard the write: on a read-only dir or full disk, cat fails and we must not
  # print the success line.
  if ! cat > "$target" <<'EOF'
# <Project name>

## What this is
<1–2 lines: what the project does and who it's for.>

## Stack / layout
<Key languages, frameworks, and where the important code lives.>

## Key decisions (and why)
- <Decision> — <why we chose it; what we rejected.>

## Current state
<What works, and what is in progress right now.>

## Next / TODO
- [ ] <next step>

## Gotchas & conventions
- <Things that broke before, patterns to follow, how to run tests/lint.>

## Writer / reviewer setup
- Writer:   <path or branch>
- Reviewer: <path or branch/worktree>
EOF
  then
    print -u2 "❌ Could not write $target."
    return 1
  fi
  print "✅ Wrote $target — fill in the blanks, or ask Claude: \"update CLAUDE.md with what we did\"."
}
