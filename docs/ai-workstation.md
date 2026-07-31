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

### Claude Code settings

A couple of keys in `~/.claude/settings.json` are what actually keep sessions
resumable, which is the point of everything below.

```json
{
  "cleanupPeriodDays": 365,
  "tui": "fullscreen"
}
```

- **`cleanupPeriodDays: 365`** is the one that matters. Claude Code prunes
  on-disk session transcripts after this many days (default 30), and
  `claude --resume` / `--continue` can only reload a conversation while its
  transcript still exists. Raising it to a year means a project you set down for
  weeks is still resumable. Trade-off: transcripts sit on disk longer, so keep
  **FileVault** on (already recommended) since they are plaintext.
- **`tui: fullscreen`** runs the TUI full-screen; cosmetic.

My `~/.claude/` hooks (secret-scanning, gitignore validation) and per-project
scaffolding are not shipped here; they live in a separate dotfiles repo managed
with GNU Stow. Starting-point templates for the global instructions and skills
do ship here, see [Claude Code config and skills](#claude-code-config-and-skills).

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
but off by default, see [Security notes](#security-notes).

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
[Prompts to fill it](#prompts-to-fill-it)) than to fill it in by hand.

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
context (the exact prompt is under [Prompts to fill it](#prompts-to-fill-it)).

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

#### Example: a full multi-monitor keymap

One worked layout, an ultrawide flanked by two portrait monitors, with every
target as its own custom entry (assign the shortcuts on the entries in **Custom
Size and Position**, and leave the built-in size actions unbound so nothing is
double-bound):

| Target | Shortcuts |
|---|---|
| Ultrawide, 5 columns (left→right) | `Ctrl-Opt-1 … 5` |
| Left monitor, 4 rows (top→bottom) | `Ctrl-Opt-Q / A / Z / X` |
| Right monitor, 4 rows (top→bottom) | `Ctrl-Opt-P / ; / . / /` |

Mnemonic: left-hand keys drive the left monitor, right-hand keys the right, and
going down the keyboard goes down the screen. Columns and side rows are all
display-pinned, so one keystroke both moves the window to the right monitor and
sizes it.

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

## Lighting and eye comfort

Long coding sessions on a big, bright panel strain the eyes mostly through
*contrast*: bright screen against a dark desk and a dark wall behind it. Two
lights fix both.

### BenQ ScreenBar Halo 2 (monitor light bar)

Clamps on the top edge, centered (the weighted clip sits fine on the flat middle
of a curved ultrawide). It has two independent lights plus an ambient sensor.

**Front (task) light** — lights the keyboard/desk, not the screen:

| Setting | Value |
|---|---|
| Auto-dim | **ON** (sensor holds ~500 lux so the desk tracks the room) |
| Color temp, day | 4000–4500K (neutral) |
| Color temp, evening | 2700–3500K (warm) |
| Favorites | Save a **day** and an **evening** preset |

Save a favorite: dial the light to the look you want, **long-press the favorite
button (~3s)** until the bar blinks, then single-press it to recall.

**Rear "Halo" (bias) light** — soft glow behind the monitor, ON but low
(~10–20%), color temp matched to the Govee so the whole back-of-monitor zone
reads as one tone.

**Calibration check:** the asymmetric optics keep light off the screen. Glance at
the panel; if you see a reflection or hotspot, tilt the beam further down onto
the desk.

### Govee strip (bias / ambient)

Mounted behind the VIVO acoustic panel as a wall wash, set neutral-white and low.
It and the Halo rear light are both bias sources, so **one leads and the other
stays minimal** (Govee as the wall wash here; Halo rear kept low), and both share
a color temperature so they don't clash.

### Screen brightness and blue light

The screen is the other half of the contrast problem. Two settings and one
schedule keep it easy on the eyes.

**Match brightness to the room.** An external monitor has no ambient sensor, so
it sits at one brightness all day. Bridge that with the built-in sensor: turn on
macOS **Automatically adjust brightness** for the laptop display, and in
[MonitorControl](#monitorcontrol) enable **Sync brightness changes from Built-in
and Apple displays** so the external follows it. Also turn on **Combine hardware
and software dimming** (dims below the panel's hardware floor for a dark room,
and sidesteps the PWM backlight flicker some panels show at low brightness),
**Enable smooth brightness transitions**, and **Assume last saved settings are valid**
so the level survives a restart or wake. That last one is reported flaky on macOS
Sequoia (MonitorControl 4.3.x), so confirm the brightness actually comes back
after a reboot. Rule of thumb: a white page should look like paper under the room
light, not a lightbulb.

**Warm it in the evening.** Turn on macOS **Night Shift** and set the schedule to
**Sunset to Sunrise**, which enables it automatically each evening (the "Turn On
Until Sunrise" button is only a manual start-now and is not needed once the
schedule is set). Sunset to Sunrise needs **Location Services** on (specifically
the "Setting Time Zone" system service), because macOS computes local sunset and
sunrise from your location; if you keep Location Services off, use a **Custom**
schedule with fixed times instead. Set the color-temperature slider to moderate,
or a touch toward **More Warm**. Night Shift **may** apply to external displays
(support depends on the monitor, so check the result on that screen); use it *or*
the monitor's own low-blue-light mode, not both, or you double-warm. It shifts every
color on screen, so for color-sensitive evening work (photos, design) keep it
moderate or turn it off. For terminal and coding work, warmer is fine.

**In the monitor's OSD:** turn off whatever auto-adjusts contrast as content
changes (the brightness pumping is fatiguing). Its name varies by model: older
Samsungs have **Dynamic Contrast**, QLED/HDR ones like the ViewFinity S9 have
**Local Dimming** instead, so turn off whichever your menu actually shows. Keep
the input at its full refresh rate. The Eye Care menu also carries **Adaptive
Picture** (leave off: it auto-drives brightness and fights MonitorControl) and
**Eye Saver Mode** (leave off if you use Night Shift, or you double-warm).

**Keep one source of truth for brightness.** Drive it from MonitorControl, not
the monitor's buttons. If the OSD brightness and MonitorControl disagree (for
example a level set in the OSD at first setup), the panel and the slider drift
apart, worst with "Assume last saved settings are valid" trusting a stale cache.
Resetting the monitor to factory defaults clears the manual value on the panel,
but MonitorControl keeps its own cached brightness and can reapply it on startup
or wake. So after a reset, resync MonitorControl too: nudge its brightness slider
to write a fresh value, or toggle "Assume last saved settings are valid" off and back
on. Then MonitorControl is the single authority again.

**How MonitorControl controls each display (shown as its Control method):**

- **Hardware (Apple):** the built-in display, driven by macOS directly. Nothing
  to configure.
- **Hardware control (DDC):** a monitor on a native connection that carries DDC/CI
  (DisplayPort, HDMI, or USB-C straight to the Mac, not through a DisplayLink
  dock). One exception: the built-in HDMI port on M1 Macs and the entry-level M2
  Mac mini carries no DDC even connected directly, so use USB-C or DisplayPort
  there. MonitorControl adjusts the real backlight, and its "combine hardware and
  software dimming" range extends below the panel's floor. This is what you want
  for the screen you look at most.
- **Software (shade)**, shown with a warning icon: a DisplayLink (dock) monitor
  appears as a "virtual display" and does not pass DDC, so MonitorControl can
  only dim it with an overlay, not the real backlight. That is a fallback, so set
  those monitors' brightness with their own buttons instead (or connect them
  natively, off the dock, to get hardware control over DDC).

### Terminal colors

A terminal fills the screen, so its palette is most of what your eyes see all
day. Aim for a soft dark theme, not maximum contrast. The setting names below are
iTerm2's; other terminals have equivalents.

- **Off-black background, off-white text**, not pure `#000000` on `#ffffff`.
  Around `#15191f` background with `#dcdcdc` foreground is comfortable. Pure white
  on pure black is the harshest possible contrast and causes halation (text edges
  appearing to glow), worse with any astigmatism.
- **Bold heavier, not brighter.** Turn off **Brighten bold text** (older iTerm2
  labels it "Use bright version of ANSI colors for bold text") and do not set a
  pure-white custom bold color; let bold use the normal foreground so it reads as
  weight, not glare. Keep **Minimum Contrast** at 0 so nothing is forced harsher.
- **Opaque window**, no transparency or blur (text over anything but a solid
  color is harder to read), and a **steady, non-blinking cursor**.
- A legible monospace at a size you read without leaning in, with a little line
  spacing.
- **Apply the settings per profile and per appearance mode.** If you keep one
  profile per project, a tweak on a single profile does not propagate; each needs
  it. And with separate light/dark colors enabled, **Brighten Bold Text** and
  **Minimum Contrast** each have Dark and Light variants, so fixing it in Dark
  mode leaves Light mode untouched. Set it in both, or the glare survives where
  you did not look.

This pairs with the screen and lighting settings above: the terminal's dark
background is most of the screen's light output, so matching screen brightness to
the room is what keeps the whole picture comfortable.

## Habits

These are not tools, but they matter more than the tools do.

### A `CLAUDE.md` per project

- **What it's for:** A memory file the assistant loads automatically every
  session, holding decisions, current state, and TODOs. Update it at the end of
  a session (prompt below) and the project is still resumable three weeks later.
- **Replaces/changes:** Replaces scrolling old chat history to reconstruct what
  was done and why. This, more than tmux, is what makes long-running projects
  work.
- **Per folder, not per repo:** Claude Code loads `CLAUDE.md` by directory, so
  the file lives in the folder you work in (where `initclaude` writes it). Keep a
  subfolder file about that component's specifics; do not restate the whole repo.
  Three behaviors matter (all in the Claude Code memory docs):
  - **Stacking depends on where you launch.** Launch in the subfolder
    (`proj <subfolder>`) and its file loads at startup on top of any at the repo
    root. Launch at the repo root and the subfolder file is on-demand: it loads
    only when Claude reads a file down there.
  - **Subfolder files do not survive `/compact`.** A root `CLAUDE.md` is
    re-injected after compaction; a nested one is not. It reloads only the next
    time Claude reads a file in that subfolder. In the long sessions this page is
    built around, a subfolder file can quietly stop applying mid-session.
  - **Confirm what loaded** with `/context`, then check the list under Memory
    files. That is the check for "did my CLAUDE.md actually load."

#### Prompts to fill it

Used by the flows in [Project workflow](#project-workflow):

- **Ongoing project:** at the end of a session, "update CLAUDE.md with what we
  did and decided." It builds up as you work.
- **Cold or existing folder:** to populate the fresh template, "Fill in the
  CLAUDE.md in this folder (the current directory, whether it is the repo root or
  a subfolder). Do not move it to the repo root. Describe THIS folder: base it on
  this folder's code and docs, this session, and relevant memory. You may pull
  context from parent or sibling folders where it helps explain this folder, but
  keep the file about this folder, not the whole repo. Do not invent; mark
  anything you cannot confirm as unverified. Show the diff before writing." The
  folder's code is ground truth; the session and memory carry recent decisions
  and half-done state not yet in the code (on a true cold start, a folder never
  opened with Claude, the code is the only source with anything in it). Then skim
  the result for two things: accuracy, and disclosure. The file is committed with
  the folder, but the session and memory can hold what the repo should not
  (client names, incident detail, internal hostnames, pasted secrets). A wrong or
  oversharing CLAUDE.md is worse than a blank one, since it is trusted every
  session.

### One tmux session per project

- **What it's for:** Each project gets its own session, often with writer and
  reviewer as two panes. `proj` jumps between them.
- **Replaces/changes:** Replaces re-establishing your working context every time
  you switch tasks.

For the writer/reviewer split, separate folders work, but a
[`git worktree`](https://git-scm.com/docs/git-worktree) per repo is cleaner: one
working directory per branch, shared history, so both can run at once on
different branches.

## Claude Code config and skills

Starting-point Claude Code config lives in [`../claude/`](../claude/), kept
separate from the shell and display config so it can grow as you add skills.
(For the `~/.claude/settings.json` keys that keep sessions resumable, see
[Claude Code settings](#claude-code-settings) above.)

- [`claude/CLAUDE.example.md`](../claude/CLAUDE.example.md) is a template for the
  global instructions Claude Code loads every session (writing voice, git
  hygiene, security, memory). It carries the `.example` suffix on purpose: a file
  literally named `CLAUDE.md` in this repo would be loaded as live directives for
  anyone working here. Copy it to `~/.claude/CLAUDE.md` and make the rules yours.
  This is the global config, distinct from the
  [per-project `CLAUDE.md`](#a-claudemd-per-project) that `initclaude` scaffolds.
- [`claude/skills/`](../claude/skills/) holds one folder per skill. Each is a
  `SKILL.md` that Claude invokes when a task matches its description.
  - [`writing-voice`](../claude/skills/writing-voice/) captures your writing
    voice across professional and personal registers so drafts sound like you.
    It ships as a template.
  - [`fact-check`](../claude/skills/fact-check/) checks the technical claims in a
    diff, file, commit, or PR against the toolchain before you ship them, so
    unverified statements do not land in durable artifacts. Ready to use as-is:
    manual only, and unable to use the Write or Edit tools (`disallowed-tools`),
    though it can still run shell commands with your approval.

To install a skill, fill in any bracketed placeholders first (`writing-voice` is
a template to complete; `fact-check` is ready as-is), then copy the folder into
`~/.claude/skills/`. A template copied with its placeholders still matches its
description, so Claude would load the empty prompts as guidance, which is worse
than not having the skill at all. Both your `~/.claude/CLAUDE.md` and the skills
are good candidates for a dotfiles repo so they restore on a new machine.

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
