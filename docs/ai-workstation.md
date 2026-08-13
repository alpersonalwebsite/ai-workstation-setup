# AI Workstation

The tools I use, what each one is for, and what it changes about the way I
worked before. Everything below is macOS.

Most of it is installed by [`../setup.sh`](../setup.sh). The one-line install
commands are listed per tool in case you want to pick and choose.

## Where to start

Read in this order. The first two are what you need to get working; the third is
comfort and can be skipped entirely.

1. **[Terminal and shell](terminal.md)** sets up tmux with session restore, fzf,
   and the `proj` and `initclaude` helpers that put a project one command away.
2. **[Claude Code config](claude-code.md)** covers global instructions, skills,
   hooks, the status line, keeping all of it in a dotfiles repo with Stow, cost
   visibility, and running two accounts side by side.
3. **[Display and comfort](workspace.md)** covers window management, monitor
   arrangement, lighting, brightness and dark mode. Independent of the rest, so
   skip it if you only came for the Claude Code setup.

Prerequisites and security notes stay on this page, since they apply to all
three.

## Prerequisites

### [Claude Code](https://claude.com/claude-code)

- **What it's for:** The AI coding assistant this whole setup is arranged around.
- **Changes:** It is the thing doing the work. The rest of this page exists to
  keep its sessions alive and its context accurate.

## Habits

These are not tools, but they matter more than the tools do.

- [A `CLAUDE.md` per project](claude-code.md#a-claudemd-per-project), so a new
  session starts from what the last one knew.
- [One tmux session per project](terminal.md#one-tmux-session-per-project), so the
  work survives closing the window.

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

## What is in each file

### Terminal and shell

- [Terminal](terminal.md#terminal)
  - [tmux (+ resurrect, continuum, sensible, yank)](terminal.md#tmux--resurrect-continuum-sensible-yank)
  - [fzf](terminal.md#fzf)
- [Shell commands](terminal.md#shell-commands)
  - [`proj`](terminal.md#proj)
  - [`initclaude`](terminal.md#initclaude)
  - [Project workflow](terminal.md#project-workflow)
  - [Surviving a restart](terminal.md#surviving-a-restart)
- [One tmux session per project](terminal.md#one-tmux-session-per-project)

### Claude Code config

- [Claude Code settings](claude-code.md#claude-code-settings)
- [Claude Code config and skills](claude-code.md#claude-code-config-and-skills)
  - [Keep `~/.claude` in a dotfiles repo with GNU Stow](claude-code.md#keep-claude-in-a-dotfiles-repo-with-gnu-stow)
  - [Cost and usage visibility](claude-code.md#cost-and-usage-visibility)
- [A second Claude Code account, side by side](claude-code.md#a-second-claude-code-account-side-by-side)
- [A `CLAUDE.md` per project](claude-code.md#a-claudemd-per-project)
  - [Prompts to fill it](claude-code.md#prompts-to-fill-it)

### Display and comfort

- [Window and display management](workspace.md#window-and-display-management)
  - [Rectangle](workspace.md#rectangle)
  - [Lunar](workspace.md#lunar)
  - [displayplacer](workspace.md#displayplacer)
- [Lighting and eye comfort](workspace.md#lighting-and-eye-comfort)
  - [BenQ ScreenBar Halo 2 (monitor light bar)](workspace.md#benq-screenbar-halo-2-monitor-light-bar)
  - [Govee strip (bias / ambient)](workspace.md#govee-strip-bias--ambient)
  - [Screen brightness and blue light](workspace.md#screen-brightness-and-blue-light)
  - [Terminal colors](workspace.md#terminal-colors)
  - [Dark mode across apps and the web](workspace.md#dark-mode-across-apps-and-the-web)
