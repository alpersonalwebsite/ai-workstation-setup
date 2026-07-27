# AI Workstation

These are some of the tools I use.

## Pre reqs tools

- Claude Code

## Tools

- tmux (+ resurrect, continuum, sensible, yank)
  - What it's for: Keeps terminal sessions alive when you close a window, disconnect, or reboot
  - Replaces/changes: Adds a layer inside your terminal. Doesn't replace iTerm2, runs inside it. tmux windows/panes can replace juggling iTerm2 tabs
- fzf
  - What it's for: Fuzzy search (the picker that proj uses)
  - Replaces/changes: Nothing. It's a helper tool
- Rectangle
  - What it's for: Snap/tile windows with keyboard shortcuts across the 49"
  - Replaces/changes: Replaces dragging windows by hand. Took over macOS's drag-to-edge tiling (you disabled the built-in one)
- MonitorControl
  - What it's for: Control external monitor brightness from the keyboard
  - Replaces/changes: Replaces reaching for the monitor's joystick (not working over USB-C yet; will retest on DisplayPort)
- displayplacer
  - What it's for: Command-line tool to read/set display modes
  - Replaces/changes: Nothing. I used it to diagnose the 60Hz issue
- proj (shell command, in ~/.claude-proj.zsh)
  - What it's for: Fuzzy-pick a Claude project, then jump into its folder + tmux session
  - Replaces/changes: Replaces manually hunting for the folder and cd-ing into it
- initclaude (shell command, in ~/.claude-proj.zsh)
  - What it's for: Creates a CLAUDE.md memory file in a project
  - Replaces/changes: Nothing new, just a template

## Good Habits

- CLAUDE.md habit (not a tool)
  - What it's for: A memory file per project you update at the end of sessions, so Claude remembers decisions after weeks
  - Replaces/changes: Replaces relying on old chat history to recall what was done
