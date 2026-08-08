# AI Workstation Setup

Notes, configuration, and tooling for working day to day with an AI coding
assistant, collected while my team adopted **Spec-Driven Development (SDD)**.

SDD means the specification is the artifact you maintain, not a document you
write once and abandon. You describe the intended behavior first, the assistant
implements against that description, and the spec stays the reference you review
changes against. In practice that shifts most of the effort from typing code to
writing precise intent and keeping context durable across sessions, which is
what most of this repo is about.

This is a personal collection rather than a framework. Take what is useful.

## What is here

| Path | What it is |
|---|---|
| [`docs/ai-workstation.md`](docs/ai-workstation.md) | The tools I use, what each is for, and what it replaces |
| [`setup.sh`](setup.sh) | Idempotent installer for the terminal side of the setup |
| [`config/tmux.conf`](config/tmux.conf) | tmux configuration (persistent sessions, big scrollback) |
| [`config/claude-proj.zsh`](config/claude-proj.zsh) | `proj` and `initclaude` shell functions |
| [`claude/CLAUDE.example.md`](claude/CLAUDE.example.md) | Template global instructions for Claude Code (copy to `~/.claude/CLAUDE.md`) |
| [`claude/skills/`](claude/skills/) | Claude Code skills, one folder each (e.g. `writing-voice`) |
| [`claude/statusline.sh`](claude/statusline.sh) | Status-line script (model, context use, session cost, branch); copy to `~/.claude/statusline.sh` |
| [`claude/agents/`](claude/agents/) | Claude Code subagents (e.g. `code-reviewer`: diff/PR review, read-only for writes, `Bash`/`WebFetch` still active, see docs); copy to `~/.claude/agents/` |
| [`claude/hooks/`](claude/hooks/) | Four hook scripts (gitignore check, gitleaks on write, `~/.claude` scan, uncommitted warning); need `jq`, two need `gitleaks` |
| [`claude/settings.example.json`](claude/settings.example.json) | Wires the hooks and status line; copy to `~/.claude/settings.json` or merge into yours |

## Quick start (macOS)

```bash
git clone https://github.com/alpersonalwebsite/ai-workstation-setup.git
cd ai-workstation-setup
# Run ONE of these, not both:
./setup.sh            # tmux + plugins + config + fzf + proj/initclaude
# or
./setup.sh --apps     # all of the above, plus Rectangle, iTerm2, Lunar (paid; MonitorControl is free)
```

The script is safe to re-run: every step checks before acting, and re-running
with nothing to change leaves your machine untouched. Any file it would
overwrite (`~/.tmux.conf`, `~/.claude-proj.zsh`) is backed up first, and only
when the contents actually differ, so repeat runs do not accumulate backups.
Pass `--assume-yes` for unattended runs. Read
[`docs/ai-workstation.md`](docs/ai-workstation.md) for what each piece does and
why it is there.

Then open a shell and run `proj` to fuzzy-pick a project, or `initclaude` inside
a project folder to scaffold a `CLAUDE.md`.

The [`claude/`](claude/) templates (global instructions, settings, hooks, a status
line, skills, and subagents) are not installed by `setup.sh`; copy them into
`~/.claude/` by
hand. See
[Claude Code config and skills](docs/ai-workstation.md#claude-code-config-and-skills).

## What this fetches

`setup.sh` downloads and runs code from the internet. Worth knowing what, from
where, and how pinned it is before you run it:

| What | Source | Pinned? |
|---|---|---|
| Homebrew installer | `raw.githubusercontent.com/Homebrew/install/HEAD/install.sh` | **No**, fetched from `HEAD` |
| TPM (tmux plugin manager) | `github.com/tmux-plugins/tpm` | **Yes**, tag `v3.1.0`, commit verified after clone |
| tmux plugins (sensible, yank, resurrect, continuum) | `github.com/tmux-plugins/*` via TPM | **No**, TPM pulls each default branch |
| tmux, fzf, and the `--apps` casks | Homebrew formulae/casks | No, current versions |

Notes on the two unpinned cases:

- **The Homebrew installer** is piped from a remote URL into `bash` and runs as
  you. That is Homebrew's own documented install method, but it is still remote
  code executing with your privileges, and `HEAD` means the contents can change
  between runs. The script prints the URL and asks for confirmation before doing
  it, and skips the step entirely if `brew` is already present. If you would
  rather not have a script do this at all, install Homebrew yourself from
  [brew.sh](https://brew.sh) first.
- **tmux plugins** are fetched unpinned by TPM, which has no lockfile mechanism.
  Pinning TPM does not pin what TPM pulls. All four plugins come from the
  [tmux-plugins](https://github.com/tmux-plugins) org and, as reviewed at the
  time of writing, run locally and make no network calls of their own. Treat
  that as an observation about the revisions I looked at, not a standing
  guarantee: because the branches are mutable, what you install may not be what
  I reviewed. To pin them, clone each plugin yourself at a chosen tag into
  `~/.tmux/plugins/` and drop the `set -g @plugin` lines from `tmux.conf`.

To bump the TPM pin, change `TPM_VERSION` and `TPM_COMMIT` in `setup.sh`
together. CI fails if they disagree with the upstream tag.

## Not here yet

The parts of the SDD workflow I still want to write up:

- Prompt and spec templates (the actual SDD artifacts)
- Reviewer setup using `git worktree`, one working directory per branch
- Longer-form walkthrough of a feature from spec to merged PR

## Prerequisites

- macOS. The scripts assume Homebrew and zsh. If Homebrew is missing, `setup.sh`
  offers to run its official installer, see [What this fetches](#what-this-fetches).
- [Claude Code](https://claude.com/claude-code), the CLI this workflow is built
  around. Everything here is about keeping context and sessions alive around it.
- **FileVault on.** Not needed for the defaults as shipped, but required before
  you enable the one opt-in that writes terminal contents to disk, see below.

## Security defaults

Two choices here are deliberately more conservative than the tools' own
defaults, because a config in a public repo becomes everyone's default.

**Terminal scrollback is not persisted.** `tmux-resurrect` can save pane
contents so scrollback survives a restart, and `config/tmux.conf` ships with
`@resurrect-capture-pane-contents` explicitly set to `'off'`. Turning it on
writes whatever your terminal printed, which can include tokens, keys, or
command output echoed by other tools, to
`~/.local/share/tmux/resurrect/` in **plaintext**. If you enable it, turn on
FileVault first (System Settings > Privacy & Security > FileVault) so that file
is encrypted at rest. Session layout and working directories are saved either
way; this only affects the text in your panes.

**Nothing in your home directory is overwritten without a backup.** Both
`~/.tmux.conf` and `~/.claude-proj.zsh` are copied to a timestamped `.backup.`
file before being replaced, and are left alone entirely when identical.

## License

[MIT](LICENSE)
