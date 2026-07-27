# AI Workstation

The tools I use, what each one is for, and what it changes about the way I
worked before. Everything below is macOS.

Most of it is installed by [`../setup.sh`](../setup.sh). The one-line install
commands are listed per tool in case you want to pick and choose.

## Prerequisites

### [Claude Code](https://claude.com/claude-code)

- **What it's for:** The AI coding assistant this whole setup is arranged around.
- **Changes:** It is the thing doing the work. The rest of this page exists to
  keep its sessions alive and its context accurate.

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
scrollback, relaunch `claude` in restored panes, true color, `prefix + r` to
reload. Restoring pane scrollback across restarts is available but off by
default, see [Security notes](#security-notes).

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

## Window and display management

### [Rectangle](https://rectangleapp.com/)

```bash
brew install --cask rectangle
```

- **What it's for:** Snap and tile windows with keyboard shortcuts, which is
  what makes a very wide monitor usable.
- **Replaces/changes:** Replaces dragging windows by hand, and replaces macOS's
  built-in drag-to-edge tiling (disable the built-in one to avoid conflicts:
  System Settings > Desktop & Dock > Tiled windows).

On an ultrawide, the free version's thirds (`Ctrl-Opt-D` / `F` / `G`) give three
full-height columns. Rectangle Pro or [Moom](https://manytricks.com/moom/) can
save a custom 4- or 5-column grid if you want more.

### [MonitorControl](https://github.com/MonitorControl/MonitorControl)

```bash
brew install --cask monitorcontrol
```

- **What it's for:** Control external monitor brightness from the keyboard.
  macOS brightness keys do not drive most non-Apple external monitors on their
  own; this uses DDC/CI to do it.
- **Replaces/changes:** Replaces reaching for the monitor's physical joystick.

Grant it System Settings > Privacy & Security > Accessibility. It works over a
native USB-C or DisplayPort connection. It does not work through a DisplayLink
dock, since DDC does not pass through, so monitors on a dock still need their
physical buttons.

### [displayplacer](https://github.com/jakehilborn/displayplacer)

```bash
brew install displayplacer
```

- **What it's for:** Command-line tool to read and set display modes. Useful for
  confirming what resolution and refresh rate a monitor is actually running at,
  rather than what you assume it is.
- **Replaces/changes:** Nothing. It is a diagnostic tool.

Worth checking on a high-resolution ultrawide: if the display offers only 60 Hz
at full resolution, the cause is almost always the port or the cable, not the
monitor's capability.

- Prefer USB-C (DP Alt Mode) or DisplayPort over HDMI, and use a full-spec cable.
- USB-C is not automatically equivalent to DisplayPort. On many monitors the
  USB-C port shares its bandwidth with USB data and hub duties, which can cap it
  at 60 Hz at full resolution. On my 49" Samsung this is exactly what happens:
  USB-C tops out at 60 Hz and only the dedicated DisplayPort 1.4 input gives
  120 Hz. If USB-C caps out, try the DisplayPort input before assuming the panel
  or the cable is the problem.
- Check the monitor's on-screen menu too. Many have a USB-C bandwidth or
  "DisplayPort version" setting that has to be raised manually.
- Do not route a high-resolution, high-refresh panel through a USB 3.0
  DisplayLink dock. Keep it on a native port and put lower-resolution secondary
  monitors on the dock.

## Habits

These are not tools, but they matter more than the tools do.

### A `CLAUDE.md` per project

- **What it's for:** A memory file the assistant loads automatically every
  session, holding decisions, current state, and TODOs. Update it at the end of
  a session ("update CLAUDE.md with what we did and decided") and the project is
  still resumable three weeks later.
- **Replaces/changes:** Replaces scrolling old chat history to reconstruct what
  was done and why. This, more than tmux, is what makes long-running projects
  work.

### One tmux session per project

- **What it's for:** Each project gets its own session, often with writer and
  reviewer as two panes. `proj` jumps between them.
- **Replaces/changes:** Replaces re-establishing your working context every time
  you switch tasks.

For the writer/reviewer split, separate folders work, but a
[`git worktree`](https://git-scm.com/docs/git-worktree) per repo is cleaner: one
working directory per branch, shared history, so both can run at once on
different branches.

## Security notes

- tmux and its plugins run locally with no telemetry. TPM only uses the network
  to download plugin code when you install or update.
- TPM itself is pinned to a tag in `setup.sh` and its commit is verified after
  cloning, so a moved tag aborts the install. The plugins TPM then pulls are
  **not** pinned, since TPM has no lockfile. See
  [What this fetches](../README.md#what-this-fetches).
- tmux-resurrect can persist pane scrollback to
  `~/.local/share/tmux/resurrect/` in plaintext, which means whatever your
  terminal printed, including anything another tool echoed. This config ships
  with it **off**. If you want scrollback to survive a restart, uncomment
  `@resurrect-capture-pane-contents 'on'` in
  [`../config/tmux.conf`](../config/tmux.conf) and keep FileVault on so the
  saved state is encrypted at rest. Session layout and working directories are
  still saved either way.
- Confirm your organization allows Homebrew and third-party open-source installs
  before running the setup script on a work machine.
