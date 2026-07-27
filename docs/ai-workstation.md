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

### Project workflow

`proj` only lists projects Claude has already opened, so it is for *resuming*,
not *creating*.

**New project** (bootstrap it once):

```bash
mkdir my-project && cd my-project
initclaude                 # optional: scaffold CLAUDE.md
tmux new -s my-project     # persistent session, named after the folder
claude                     # first run registers it; now it shows up in proj
```

**Resume a project** (anything Claude has opened before):

```bash
proj                       # fuzzy-pick -> its folder + a tmux session
claude --resume            # reload the conversation (--continue = most recent)
```

End a session with "update CLAUDE.md with what we did" so the next resume starts
with full context.

> Note: `proj` names its tmux session with a hash suffix, so it will not
> reattach a session you hand-named with `tmux new -s`; use
> `tmux attach -t <name>` for those. Pick one convention to avoid duplicate
> sessions for the same project.

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
full-height columns. That is the ceiling for free Rectangle: its built-in
column splits stop at thirds, and its anchor-based custom sizes (center, edges,
corners) cannot place the in-between columns of a 4- or 5-column layout. For
more columns you need Rectangle Pro (below) or [Moom](https://manytricks.com/moom/).

#### Rectangle Pro: 4 or 5 equal full-height columns

```bash
brew install --cask rectangle-pro
```

Rectangle Pro ($9.99 one-time, 10-day trial) is a superset of the free
Rectangle. You can keep both installed, but run only one at a time, otherwise
they fight over the same hotkeys, so quit or remove the free app once your
settings are in Pro. It adds custom **Size and Position** entries. The key is
the **Custom origin** position type, which exposes explicit X/Y fields, so you
can place every column, not just left/center/right.

Create one entry per column (Settings > Custom Size and Position > `+` > New
Size/Position > Position: **Custom origin**). Values **≤ 1** are fractions of
the screen (`0.2` = 20%, `1.0` = 100%); values **> 1** are pixels; blank keeps
the current value.

Five equal full-height columns, `Y = 0`, `H = 1.0`, `W = 0.2`:

| Column | X | Shortcut |
|---|---|---|
| 1 | 0   | `Ctrl-Opt-1` |
| 2 | 0.2 | `Ctrl-Opt-2` |
| 3 | 0.4 | `Ctrl-Opt-3` |
| 4 | 0.6 | `Ctrl-Opt-4` |
| 5 | 0.8 | `Ctrl-Opt-5` |

For four columns, use `W = 0.25` and `X = 0 / 0.25 / 0.5 / 0.75` (bind to
`Ctrl-Opt-Shift-1..4` so both sets coexist). If a numeric shortcut will not
record, it collides with another binding, use the `Shift` variant.

To place windows, put them on the ultrawide, then press the column's shortcut.

**On "use as a snap target":** enabling it on a column also turns that column
into a drag zone, so dragging *any* window (a browser, say) will try to snap it
into a 20%-wide strip. If that is unwanted, either leave snap targets off and
drive the columns by keyboard only, or set Rectangle Pro to snap on drag only
while a modifier is held (Settings > Snapping). The keyboard shortcuts work
regardless.

#### Rows and grids

Rows work exactly like columns, you just vary `Y`/`H` instead of `X`/`W`. For a
quick two-stack, the built-in halves are enough: `Ctrl-Opt-Up` (top half) and
`Ctrl-Opt-Down` (bottom half). For anything else, use Custom Size and Position.

Four equal full-height-width rows, `X = 0`, `W = 1`, `H = 0.25`:

| Row | Y |
|---|---|
| 1 | 0 |
| 2 | 0.25 |
| 3 | 0.5 |
| 4 | 0.75 |

Because `X`, `Y`, `W`, `H` are independent, any grid cell is expressible, a 2x2
quadrant is `W = 0.5, H = 0.5` at the four `X`/`Y` corners; a wide log pane under
five columns is a full-width `Y = 0.5, H = 0.5` row plus the five-column set
above it. Each cell is its own entry with its own shortcut.

**Targeting a specific display.** A custom entry can either follow the focused
window's current display, or be pinned to one monitor via the **Destination
display** field. Pinning is handy for portrait side monitors: e.g. two entries
"Row 2" and "Row 3" pinned to the left monitor place two stacked terminals there
with one keystroke each, no need to move the window over first. Duplicate the set
per monitor if you want the same rows on each. The trade-off: a pinned entry is
tied to that display's identity, so unplugging or rearranging monitors can change
the ID and the entry may need recreating.

### [MonitorControl](https://github.com/MonitorControl/MonitorControl)

```bash
brew install --cask monitorcontrol
```

- **What it's for:** Control external monitor brightness from the keyboard.
  macOS brightness keys do not drive most non-Apple external monitors on their
  own; this uses DDC/CI to do it.
- **Replaces/changes:** Replaces reaching for the monitor's physical joystick.

Grant it System Settings > Privacy & Security > Accessibility.

How well it works depends on the connection, and it is worth treating as
something to test rather than assume:

- **DisplayPort, or USB-C in DP Alt Mode:** usually works, but not always. DDC
  support varies by monitor, by cable, and sometimes by which input you use on
  the same monitor. If brightness keys do nothing, try the other input before
  concluding the app is broken.
- **Through a DisplayLink dock:** does not work. DDC does not pass through, so
  monitors on a dock still need their physical buttons.

If it does not work for a given display, that is usually the monitor or the
link, not MonitorControl.

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

- tmux runs locally. TPM only uses the network to download plugin code when you
  install or update. The four plugins made no network calls of their own in the
  revisions I reviewed, but they are fetched from mutable branches, so that is
  an observation rather than a guarantee about what you will get.
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
