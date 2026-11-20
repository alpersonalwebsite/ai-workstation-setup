# AI Workstation Setup

Configuration and notes for working day to day with an AI coding assistant on macOS.
It covers the environment around the assistant: a terminal whose sessions survive a reboot, and Claude Code config you keep in version control instead of copying by hand.

## Why it exists

I collected this while my team adopted **Spec-Driven Development (SDD)**, where the specification is the artifact you maintain rather than a document you write once and abandon.
That moves the effort from typing code to writing precise intent and keeping context alive across sessions, and everything here supports that second part:

- tmux sessions that survive closing the window and restarting the machine
- Claude Code global instructions, skills, hooks, a status line and a subagent, kept in a dotfiles repo
- live session cost in the status line, plus day and week from Claude Code itself (month and longer needs one optional third-party tool)
- two Claude Code accounts running side by side from the same project

## Status and limits

- **macOS only.** The scripts assume Homebrew and zsh.
- **A personal collection, not a framework.** Take what helps and skip the rest.
- **`setup.sh` does not install the Claude Code config.** It sets up the terminal side, plus the window and display apps with `--apps`. Nothing under [`claude/`](claude/) is installed for you; [placing those files](#getting-the-claude-files-into-place) is a separate, manual step.
- **Only TPM is pinned.** The Homebrew installer, the tmux plugins, and the Homebrew formulae and casks are all fetched at whatever is current. [What this fetches](#what-this-fetches) has the details.
- **The SDD artifacts themselves are not written up yet:** the prompt and spec templates, a reviewer setup using `git worktree` (one working directory per branch), and a walkthrough of a feature from spec to merged PR.

## Prerequisites

- macOS with zsh. If Homebrew is missing, `setup.sh` offers to run its official installer.
- [Claude Code](https://claude.com/claude-code), the CLI this setup is built around.
- For the hooks in [`claude/hooks/`](claude/hooks/): `jq` for four of them, and `gitleaks` for two of those four (a missing `gitleaks` is reported at session start). The secret-echo guard needs `python3` instead and fails closed without it: a missing interpreter denies the tool call, by design.
- **FileVault on**, but only if you enable the one opt-in that writes terminal contents to disk (see [Security defaults](#security-defaults)).

Before running `setup.sh` on a work machine, confirm your organization allows Homebrew and third-party open-source installs.

## Quick start

```bash
git clone https://github.com/alpersonalwebsite/ai-workstation-setup.git
cd ai-workstation-setup
# Run ONE of these, not both:
./setup.sh            # tmux + plugins + config + fzf + proj/initclaude
# or
./setup.sh --apps     # all of the above, plus Rectangle, iTerm2, Lunar (paid; MonitorControl is free)
```

The script is safe to re-run: every step checks before acting, and a run with nothing to change leaves your machine untouched.
Any file it would overwrite (`~/.tmux.conf`, `~/.claude-proj.zsh`) is backed up first, and only when the contents differ, so repeat runs do not pile up backups.
Pass `--assume-yes` for unattended runs.

Then open a new shell and run `proj` to fuzzy-pick a project, or `initclaude` inside a project folder to scaffold a `CLAUDE.md`.

### Check it worked

`setup.sh` is quiet when it succeeds, so confirm rather than assume.
Use a **new** shell, since `proj` and `initclaude` only exist in shells started after the install:

```bash
tmux -V                    # tmux 3.x
fzf --version              # a version number, not "command not found"
type proj initclaude       # both: shell function from ~/.claude-proj.zsh
ls -d ~/.tmux/plugins/tpm  # the plugin manager was cloned
```

Inside tmux, `prefix + I` installs the plugins on first run.
[`config/tmux.conf`](config/tmux.conf) keeps tmux's default prefix, `Ctrl-b`.

### Getting the `claude/` files into place

There are two ways, and they end in different places:

- **Copy, to try it out.** Copy the files you want into `~/.claude/`, `chmod +x` the shell scripts, and merge `settings.example.json` into your own `settings.json`. Fastest, and fine while you decide what to keep.
- **Stow, to keep it.** Put the files in a dotfiles repo and let GNU Stow symlink them into `~/.claude/`, so your edits are version-controlled and come back on a new machine. This is how the setup runs day to day, so read [Keep `~/.claude` in a dotfiles repo with GNU Stow](docs/claude-code.md#keep-claude-in-a-dotfiles-repo-with-gnu-stow) before you copy anything and save yourself moving the same files twice.

Either way, [Claude Code config and skills](docs/claude-code.md#claude-code-config-and-skills) says what each file does and how to check it is live.

## What this fetches

`setup.sh` downloads and runs code from the internet, so here is what, from where, and how pinned:

| What | Source | Pinned? |
|---|---|---|
| Homebrew installer | `raw.githubusercontent.com/Homebrew/install/HEAD/install.sh` | **No**, fetched from `HEAD` |
| TPM (tmux plugin manager) | `github.com/tmux-plugins/tpm` | **Yes**, tag `v3.1.0`, commit verified after clone |
| tmux plugins (sensible, yank, resurrect, continuum) | `github.com/tmux-plugins/*` via TPM | **No**, TPM pulls each default branch |
| tmux, fzf, and the `--apps` casks | Homebrew formulae and casks | No, current versions |

The three unpinned cases:

- **The Homebrew installer** is piped from a remote URL into `bash` and runs as you.
  That is Homebrew's own documented install method, but it is still remote code running with your privileges, and `HEAD` means its contents can change between runs.
  The script prints the URL and asks before running it, and skips the step if `brew` is already installed.
  If you would rather no script did this, install Homebrew yourself from [brew.sh](https://brew.sh) first.
- **The tmux plugins** are fetched unpinned by TPM, which has no lockfile, so pinning TPM does not pin what TPM pulls.
  All four come from the [tmux-plugins](https://github.com/tmux-plugins) org and, in the revisions I reviewed, run locally and make no network calls of their own.
  That is an observation about those revisions, not a guarantee: the branches are mutable, so what you install may not be what I reviewed.
  To pin them, clone each plugin yourself at a chosen tag into `~/.tmux/plugins/` and drop the `set -g @plugin` lines from `tmux.conf`.
- **The Homebrew formulae and casks** (tmux, fzf, and the `--apps` apps) are installed with a plain `brew install` and no version, so you get whatever Homebrew currently ships.
  That is ordinary Homebrew behavior, but it means two runs months apart can install different versions.

To bump the TPM pin, change `TPM_VERSION` and `TPM_COMMIT` in `setup.sh` together.
CI fails if they disagree with the upstream tag.

## Security defaults

Two choices here are deliberately more conservative than the tools' own defaults, because a config in a public repo becomes everyone's default.

**Terminal scrollback is not saved to disk.**
`tmux-resurrect` can save pane contents so scrollback survives a restart, and [`config/tmux.conf`](config/tmux.conf) ships with `@resurrect-capture-pane-contents` set to `'off'`.
Turning it on writes whatever your terminal printed, which can include tokens, keys, or output another tool echoed, to `~/.local/share/tmux/resurrect/` in **plaintext**.
If you enable it, turn on FileVault first (System Settings > Privacy & Security > FileVault) so that file is encrypted at rest.
Session layout and working directories are saved either way; this only affects the text in your panes.

**Nothing in your home directory is overwritten without a backup.**
Both `~/.tmux.conf` and `~/.claude-proj.zsh` are copied to a timestamped `.backup.` file before being replaced, and left alone when identical.

## What is in the repo

| Path | What it is |
|---|---|
| [`docs/ai-workstation.md`](docs/ai-workstation.md) | Start here: reading order, habits, security notes |
| [`docs/terminal.md`](docs/terminal.md) | tmux with session restore, fzf, `proj` and `initclaude`, the project workflow, surviving a reboot |
| [`docs/claude-code.md`](docs/claude-code.md) | Claude Code config, skills, hooks, status line, Stow, cost visibility, two accounts side by side |
| [`docs/workspace.md`](docs/workspace.md) | Window management, monitor arrangement, lighting, brightness, dark mode |
| [`setup.sh`](setup.sh) | Idempotent installer for the terminal side, plus the window and display apps with `--apps` |
| [`config/tmux.conf`](config/tmux.conf) | tmux configuration (persistent sessions, big scrollback) |
| [`config/claude-proj.zsh`](config/claude-proj.zsh) | The `proj` and `initclaude` shell functions |
| [`claude/CLAUDE.example.md`](claude/CLAUDE.example.md) | Template global instructions; copy to `~/.claude/CLAUDE.md` |
| [`claude/skills/`](claude/skills/) | Seven skills, one folder each (`writing-voice`, `security-audit` and others). Four are manual only, which stops Claude invoking them at all: [see why](docs/claude-code.md#claude-code-config-and-skills) |
| [`claude/statusline.sh`](claude/statusline.sh) | Status line: launching command, model, context use, session cost, working directory, branch; copy to `~/.claude/statusline.sh` |
| [`claude/agents/`](claude/agents/) | Subagents, such as `code-reviewer` for diff and PR review (plan mode, so no edits, though `Bash` and `WebFetch` stay available); copy to `~/.claude/agents/` |
| [`claude/hooks/`](claude/hooks/) | Six hooks: gitignore check, gitleaks on write, `~/.claude` scan, uncommitted-work warning, secret-echo guard, missing-gitleaks warning. Requirements are under [Prerequisites](#prerequisites); the secret-echo guard's regression suites are in [`claude/hooks/tests/`](claude/hooks/tests/) |
| [`claude/settings.example.json`](claude/settings.example.json) | Wires the hooks and status line, and denies reads and edits of secret files (`//**/.env*`, `~/.ssh/**`, `~/.aws/credentials` and kin; the `//` anchor is load-bearing). Sets no `attribution` key, so the AI-assistance trailer follows your own policy. Copy to `~/.claude/settings.json` or merge into yours |

Some write-ups are hard to find by scrolling, so here they are by the question they answer:

| Topic | What it answers |
|---|---|
| [A second Claude Code account, side by side](docs/claude-code.md#a-second-claude-code-account-side-by-side) | Running two logins at once through `CLAUDE_CONFIG_DIR`, including the env vars that silently collapse the split back into one account |
| [Keep `~/.claude` in a dotfiles repo with GNU Stow](docs/claude-code.md#keep-claude-in-a-dotfiles-repo-with-gnu-stow) | Version-controlling your Claude config instead of copying files by hand |
| [Cost and usage visibility](docs/claude-code.md#cost-and-usage-visibility) | Live session cost, plus day, week and month spend, with nothing third-party on the always-on path |
| [Claude Code config and skills](docs/claude-code.md#claude-code-config-and-skills) | What each file in [`claude/`](claude/) does, and what "manual only" blocks |
| [Surviving a restart](docs/terminal.md#surviving-a-restart) | Getting tmux sessions and working directories back after a reboot |

## License

[MIT](LICENSE)
