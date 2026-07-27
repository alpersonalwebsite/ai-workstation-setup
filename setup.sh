#!/usr/bin/env bash
#
# Reproducible dev-terminal setup for a new Mac.
# Installs tmux + TPM + resurrect/continuum (persistent sessions), fzf, and the
# proj/initclaude shell functions. Optionally installs the GUI apps.
#
# Configs are read from ./config/ in this repo.
#
# Safe to re-run: every step checks before acting (idempotent).
# It backs up any existing ~/.tmux.conf before overwriting.
#
# Usage:
#   ./setup.sh            # core: tmux + plugins + config + fzf + proj
#   ./setup.sh --apps     # also install Rectangle, iTerm2, MonitorControl
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_APPS=false
[[ "${1:-}" == "--apps" ]] && INSTALL_APPS=true

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

# --- 1. Homebrew ------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for this script run. Test the path before eval'ing:
  # `eval "$(/missing/brew shellenv)"` exits 0 with empty output, so an
  # `||` fallback after it would be dead code.
  if [[ -x /opt/homebrew/bin/brew ]]; then       # Apple Silicon
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then        # Intel
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "Homebrew installed but not found at the expected prefix." >&2
    echo "Open a new terminal and re-run this script." >&2
    exit 1
  fi
else
  log "Homebrew already installed: $(brew --version | head -1)"
fi

# --- 2. tmux ----------------------------------------------------------------
if ! command -v tmux >/dev/null 2>&1; then
  log "Installing tmux"
  brew install tmux
else
  log "tmux already installed: $(tmux -V)"
fi

# --- 3. TPM (tmux plugin manager) ------------------------------------------
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "Cloning TPM"
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  log "TPM already present"
fi

# --- 4. tmux config ---------------------------------------------------------
# Only touch ~/.tmux.conf when it actually differs, so re-running does not pile
# up identical timestamped backups.
if cmp -s "$SCRIPT_DIR/config/tmux.conf" "$HOME/.tmux.conf" 2>/dev/null; then
  log "tmux.conf already up to date"
else
  if [[ -f "$HOME/.tmux.conf" ]]; then
    BACKUP="$HOME/.tmux.conf.backup.$(date +%s 2>/dev/null || echo old)"
    log "Backing up existing ~/.tmux.conf -> $BACKUP"
    cp "$HOME/.tmux.conf" "$BACKUP"
  fi
  log "Installing tmux.conf"
  cp "$SCRIPT_DIR/config/tmux.conf" "$HOME/.tmux.conf"
fi

# --- 5. Install plugins (headless) -----------------------------------------
# PID-based session name so we cannot collide with a real user session, and an
# EXIT trap so `set -e` bailing out of install_plugins still cleans it up.
log "Installing tmux plugins"
TMUX_SETUP_SESSION="_tpm_setup_$$"
cleanup_setup_session() { tmux kill-session -t "$TMUX_SETUP_SESSION" 2>/dev/null || true; }
trap cleanup_setup_session EXIT
tmux new-session -d -s "$TMUX_SETUP_SESSION" 2>/dev/null || true
"$HOME/.tmux/plugins/tpm/bin/install_plugins"
cleanup_setup_session
trap - EXIT

# --- 6. fzf + Claude project switcher (proj / initclaude) -------------------
if ! command -v fzf >/dev/null 2>&1; then
  log "Installing fzf (fuzzy finder, used by 'proj')"
  brew install fzf
else
  log "fzf already installed"
fi
log "Installing claude-proj.zsh (proj + initclaude)"
cp "$SCRIPT_DIR/config/claude-proj.zsh" "$HOME/.claude-proj.zsh"
# A fresh macOS install has no ~/.zshrc, so create it rather than skipping the
# wiring (which would copy the file but leave proj/initclaude never loaded).
# No symlink resolution needed: both `grep` and `>>` follow a symlink to its
# target.
ZSHRC="$HOME/.zshrc"
if [[ ! -e "$ZSHRC" ]]; then
  log "No ~/.zshrc found, creating one"
  touch "$ZSHRC"
fi
if ! grep -q 'claude-proj.zsh' "$ZSHRC"; then
  log "Sourcing claude-proj.zsh from ~/.zshrc"
  printf '\n# Claude Code project switcher (proj) + CLAUDE.md scaffold (initclaude)\n[[ -f ~/.claude-proj.zsh ]] && source ~/.claude-proj.zsh\n' >> "$ZSHRC"
else
  log "claude-proj.zsh already sourced from ~/.zshrc"
fi

# --- 7. Optional GUI apps ---------------------------------------------------
if $INSTALL_APPS; then
  log "Installing Rectangle (window tiling)"
  brew list --cask rectangle >/dev/null 2>&1 || brew install --cask rectangle
  log "Installing iTerm2"
  brew list --cask iterm2 >/dev/null 2>&1 || brew install --cask iterm2
  log "Installing MonitorControl (brightness/volume for external monitors via DDC)"
  brew list --cask monitorcontrol >/dev/null 2>&1 || brew install --cask monitorcontrol
fi

log "Done."
echo
echo "Next steps:"
echo "  - Start tmux:            tmux"
echo "  - Detach (keep alive):   Ctrl-b d"
echo "  - Reattach later:        tmux attach"
echo "  - After a reboot, run 'claude --resume' in each restored pane."
echo "  - Open a new terminal (or 'source ~/.zshrc') to pick up proj/initclaude."
$INSTALL_APPS || echo "  - Re-run with --apps to also install Rectangle, iTerm2, MonitorControl."
