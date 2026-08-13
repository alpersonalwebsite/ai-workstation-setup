# Terminal and shell

tmux with session restore, fzf, and the `proj` and `initclaude` helpers that put
a project one command away.

Part of the [AI Workstation](ai-workstation.md) setup notes.

## Terminal

### [tmux](https://github.com/tmux/tmux/wiki) (+ resurrect, continuum, sensible, yank)

```bash
brew install tmux
```

- **What it's for:** Keeps terminal sessions alive when you close a window or
  disconnect. The session keeps running on the machine and you reattach to it. A
  reboot does stop the tmux server, but resurrect and continuum bring the
  layout, windows, and working directories back, so you restart the work rather
  than rebuilding the workspace.
- **Replaces/changes:** Adds a layer inside your terminal. It does not replace
  iTerm2, it runs inside it. tmux windows and panes do replace juggling iTerm2
  tabs.

Plugins, all from the [tmux-plugins](https://github.com/tmux-plugins) org:

| Plugin | Purpose |
|---|---|
| [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) | Sane defaults |
| [tmux-yank](https://github.com/tmux-plugins/tmux-yank) | Copy selection to the system clipboard |
| [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | Save and restore sessions, panes, layout, working dirs |
| [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) | Auto-save every 15 min, auto-restore on start |

Config lives in [`../config/tmux.conf`](../config/tmux.conf): mouse on, 50k
scrollback, true color, `prefix + r` to reload. Restored panes come back as
plain shells (nothing auto-relaunched), and pane-scrollback restore is available
but off by default, see [Security notes](ai-workstation.md#security-notes).

Day-to-day keys (prefix is `Ctrl-b`):

| Action | Keys |
|---|---|
| Detach, keeps running in background | `Ctrl-b d` |
| Reattach | `tmux attach` |
| New window | `Ctrl-b c` |
| Split horizontal / vertical | `Ctrl-b "` / `Ctrl-b %` |
| Save session now | `Ctrl-b Ctrl-s` |
| Restore session | `Ctrl-b Ctrl-r` |
| Reload config | `Ctrl-b r` |
| Install plugins after editing config | `Ctrl-b I` |

After a reboot tmux restores the layout, windows, and working directories, but
not the live conversation. Run `claude --resume` in each pane to pick the
conversation back up.

### [fzf](https://github.com/junegunn/fzf)

```bash
brew install fzf
```

- **What it's for:** Fuzzy search. It is the picker that `proj` uses.
- **Replaces/changes:** Nothing. It is a helper tool.

## Shell commands

Both live in [`../config/claude-proj.zsh`](../config/claude-proj.zsh), which
`setup.sh` copies to `~/.claude-proj.zsh` and sources from `.zshrc`.

### `proj`

- **What it's for:** Fuzzy-pick one of your Claude Code projects, then jump into
  its folder and tmux session, creating the session if it does not exist. The
  list is read from `~/.claude/projects/` sorted most-recently-active first, so
  it stays usable past 20 projects. The preview pane shows that project's
  `CLAUDE.md`, so you can see where you left off before entering.
- **Replaces/changes:** Replaces manually hunting for the folder and `cd`-ing
  into it.

### `initclaude`

- **What it's for:** Scaffolds a `CLAUDE.md` memory file in the current folder,
  pre-filled with the sections worth keeping (what this is, stack, key decisions
  and why, current state, TODO, gotchas).
- **Replaces/changes:** Nothing new, it is just a template. The value is that
  the template asks the right questions.

### Project workflow

One command, `proj`, handles both new and existing projects. Its tmux session
name is derived from the folder path, so it always reattaches the *same* session
instead of spawning duplicates, no hand-naming, no `tmux attach -t <name>`.

**New project:**

```bash
mkdir my-project && cd my-project
initclaude          # optional: scaffold CLAUDE.md (project memory)
proj .              # create/attach this folder's tmux session
claude              # start Claude inside it — now persistent
```

**Existing project (no `CLAUDE.md` yet):**

```bash
proj ~/Documents/that-old-project   # cd + create/attach this folder's tmux session
initclaude                          # scaffold CLAUDE.md (refuses if one exists)
claude                              # then have Claude fill it in (see "Prompts to fill it")
```

Use `proj <dir>` with the path, not bare `proj`: bare `proj` fuzzy-picks from
projects you have already opened, and a repo never opened with Claude is not in
that list. `initclaude` never overwrites an existing `CLAUDE.md`; it refuses and
exits non-zero, so it is safe to run on any repo. For an older project with real
code, it is easier to let Claude populate the template (see
[Prompts to fill it](claude-code.md#prompts-to-fill-it)) than to fill it in by hand.

**Resume a project:**

```bash
proj                # fuzzy-pick a project you've opened before -> its session
                    # (or `proj .` if you're already in the folder)
claude --resume     # reload the conversation (--continue = most recent)
```

The picker lists projects most-recently-active first. To list alphabetically,
add `export PROJ_SORT=alpha` to `~/.zshrc.local` (default is `recent`).

**Everyday commands** (tmux prefix is `Ctrl-b`):

| Do this | Keys / command |
|---|---|
| Detach (leave it running) | `Ctrl-b` then `d` |
| List running sessions | `tmux ls` |
| Reattach the most recent | `tmux a` |
| New window (e.g. reviewer) | `Ctrl-b c` |
| Switch windows | `Ctrl-b n` / `p`, or click the bottom bar |

**Detach vs quit, and what ends a session:**

A tmux session runs on its own; detaching only unhooks it from the window. So
closing or reusing a window never loses your work, only *ending* the session
does.

| Action | Effect |
|---|---|
| `/exit` in Claude | Closes Claude; you stay at the tmux shell (session alive) |
| `Ctrl-b d` (detach) | Unhooks the window; session keeps running (reattach with `proj`) |
| Close the iTerm2 tab/window | Session keeps running |
| `exit` or `Ctrl-D` at the tmux shell | **Ends** the window → the last one ends the session |
| `tmux kill-session` | **Ends** the session |

A single `Ctrl-C` in Claude only cancels the current action, it does not quit.
Mnemonic: **`/exit` closes Claude; `exit` closes the session.**

End a work session by updating CLAUDE.md so the next resume starts with full
context (the exact prompt is under [Prompts to fill it](claude-code.md#prompts-to-fill-it)).

### Surviving a restart

A reboot stops the tmux server, so nothing is literally "live" across it, but
almost everything comes back:

| Thing | After a reboot |
|---|---|
| Claude conversations | Saved to disk; reload with `claude --resume` |
| tmux sessions (windows, panes, dirs) | Restored headlessly by continuum; panes come back as **plain shells** |
| Rectangle column/row shortcuts | Kept (they live in Rectangle's prefs) |
| Which window sat in which column | **Not** restored on its own — re-snap, or use an iTerm2 arrangement |
| iTerm2 opening at all | Only if iTerm2 is a Login Item (below) |

**Two auto-start pieces, in two different places.** Both live in **System
Settings > General > Login Items & Extensions**, but under different sections:

- **tmux LaunchAgent** (`~/Library/LaunchAgents/Tmux.Start.plist`) → shows under
  **Allow in the Background**. `@continuum-boot 'on'` (in `config/tmux.conf`)
  creates it; it arms itself the first time tmux runs after the setting is added,
  so start tmux once (`proj`) to install it. At login it starts tmux and
  continuum restores your sessions in the background.
- **iTerm2** → add it yourself under **Open at Login**. Without it, iTerm2 never
  opens and the saved arrangement never runs.

(Rectangle Pro is also under **Open at Login**; keep its own "Launch on login"
toggle enabled.)

**Restore window positions.** Rectangle keeps your shortcuts but does not
re-place windows. To bring your columns/rows back automatically, use an iTerm2
window arrangement:

1. Arrange your windows the way you want.
2. iTerm2 menu: **Window > Save Window Arrangement**, name it (e.g. `Default`).
3. iTerm2 **Settings > General > Startup**: window restoration policy →
   **Open default window arrangement**.
4. Add **iTerm2** to Login Items (see above) so it launches at boot.

**After a reboot, three steps per project:**

1. iTerm2 launches (Login Items) and its arrangement reopens your windows — but
   as **plain shells**, not attached to tmux.
2. In each window, run **`proj`**. It reattaches to the session continuum
   restored in the background (same deterministic name), dropping you back into
   the project's panes.
3. In each pane, run **`claude --resume`** (or `--continue`) to reload its
   conversation.

Step 2 is the one that's easy to skip: an arrangement-restored shell is *not*
inside tmux, so running Claude there would be outside your persistent session.
`proj` is what reconnects you.

## One tmux session per project

- **What it's for:** Each project gets its own session, often with writer and
  reviewer as two panes. `proj` jumps between them.
- **Replaces/changes:** Replaces re-establishing your working context every time
  you switch tasks.

For the writer/reviewer split, separate folders work, but a
[`git worktree`](https://git-scm.com/docs/git-worktree) per repo is cleaner: one
working directory per branch, shared history, so both can run at once on
different branches.
