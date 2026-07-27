# ~/.claude-proj.zsh
# Claude Code project switcher + CLAUDE.md scaffold.
# Installed to ~/.claude-proj.zsh by setup.sh and sourced from ~/.zshrc.
# Canonical source: alpersonalwebsite/ai-workstation-setup, config/claude-proj.zsh
#
#   proj        fuzzy-pick one of your Claude Code projects and jump into its
#               tmux session (creates it if needed). Scales to any number of projects.
#   initclaude  scaffold a CLAUDE.md (project memory) in the current folder.

# List Claude Code's known project dirs, most-recently-active first, deduped.
# Paths are read from each session's recorded `cwd` (accurate even when the
# folder name contains hyphens, which the on-disk encoding mangles).
_claude_projects() {
  emulate -L zsh
  local d cwd m
  local -a files
  for d in ~/.claude/projects/*/(N); do
    files=( "$d"*.jsonl(Nom) )   # N=nullglob, om=newest-first by mtime
    (( ${#files} )) || continue
    cwd=$(grep -ao '"cwd":"[^"]*"' "${files[1]}" 2>/dev/null | head -1 | sed 's/.*"cwd":"//; s/".*//')
    [[ -n "$cwd" && -d "$cwd" ]] || continue
    m=$(stat -f '%m' "${files[1]}" 2>/dev/null)
    printf '%s\t%s\n' "$m" "$cwd"
  done | sort -rn | cut -f2- | awk '!seen[$0]++'
}

# Fuzzy-pick a project and attach/create its tmux session.
proj() {
  emulate -L zsh
  local dir sess hash
  # No quotes around {}: fzf already substitutes it as a shell-quoted string,
  # so "{}/CLAUDE.md" would look for a literally-quoted path and never match.
  dir=$(_claude_projects | fzf \
        --prompt='project ▸ ' --reverse --height=60% \
        --preview 'test -f {}/CLAUDE.md && cat {}/CLAUDE.md || echo "(no CLAUDE.md yet — run: initclaude)"' \
        --preview-window=right:55%:wrap) || return
  [[ -n "$dir" ]] || return
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
