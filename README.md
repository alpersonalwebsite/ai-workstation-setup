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

## Quick start (macOS)

```bash
git clone https://github.com/alpersonalwebsite/ai-workstation-setup.git
cd ai-workstation-setup
./setup.sh            # tmux + plugins + config + fzf + proj/initclaude
./setup.sh --apps     # the above, plus Rectangle, iTerm2, MonitorControl
```

The script is safe to re-run: every step checks before acting, and re-running
with no changes to pull in leaves your machine untouched. It backs up an
existing `~/.tmux.conf` before overwriting, but only when the contents actually
differ, so repeat runs do not accumulate backup files. Read
[`docs/ai-workstation.md`](docs/ai-workstation.md) for what each piece does and
why it is there.

Then open a shell and run `proj` to fuzzy-pick a project, or `initclaude` inside
a project folder to scaffold a `CLAUDE.md`.

## Not here yet

The parts of the SDD workflow I still want to write up:

- Prompt and spec templates (the actual SDD artifacts)
- Reviewer setup using `git worktree`, one working directory per branch
- Longer-form walkthrough of a feature from spec to merged PR

## Prerequisites

- macOS. The scripts assume Homebrew and zsh.
- [Claude Code](https://claude.com/claude-code), the CLI this workflow is built
  around. Everything here is about keeping context and sessions alive around it.

## License

[MIT](LICENSE)
