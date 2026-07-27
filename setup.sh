#!/usr/bin/env bash
#
# Reproducible dev-terminal setup for a new Mac.
# Installs tmux + TPM + resurrect/continuum (persistent sessions), fzf, and the
# proj/initclaude shell functions. Optionally installs the GUI apps.
#
# Configs are read from ./config/ in this repo.
#
# Safe to re-run: every step checks before acting. Files it would overwrite
# (~/.tmux.conf, ~/.claude-proj.zsh) are only touched when their contents
# actually differ, and the previous version is backed up first.
#
# What this fetches from the network, so you can decide before running it:
#   - The official Homebrew installer, downloaded from raw.githubusercontent.com
#     and executed as you. Prompts for confirmation unless --assume-yes.
#   - TPM, pinned to the tag in TPM_VERSION below.
#   - tmux plugins, which TPM fetches from their default branches UNPINNED.
#     See the README "What this fetches" section.
#   - Homebrew formulae/casks: tmux, fzf, and with --apps the GUI apps.
#
# Usage:
#   ./setup.sh                 # core: tmux + plugins + config + fzf + proj
#   ./setup.sh --apps          # also install Rectangle, iTerm2, MonitorControl
#   ./setup.sh --assume-yes    # never prompt (for unattended/CI runs)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_APPS=false
ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    --apps)       INSTALL_APPS=true ;;
    --assume-yes|-y) ASSUME_YES=true ;;
    # Print the header block, stopping at the first non-comment line, so this
    # does not go stale when the header grows.
    -h|--help)    awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' \
                      "${BASH_SOURCE[0]}"; exit 0 ;;
    *)            echo "Unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

# TPM release to pin to. Bump deliberately.
#
# TPM_COMMIT must be the COMMIT the tag points at, not the tag object itself.
# These tags are annotated, so `ls-remote refs/tags/vX` returns the tag object
# and `rev-parse HEAD` after cloning returns the commit. Use the `^{}` line:
#   git ls-remote https://github.com/tmux-plugins/tpm 'refs/tags/v3.1.0*'
#   c628645...  refs/tags/v3.1.0        <- tag object, NOT this one
#   7bdb7ca...  refs/tags/v3.1.0^{}     <- the commit, use this
TPM_VERSION="v3.1.0"
TPM_COMMIT="7bdb7ca33c9cc6440a600202b50142f401b6fe21"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$1"; }

# Ask before doing something the user should knowingly consent to. Refuses to
# assume consent when there is no terminal to ask at.
confirm() {
  local prompt="$1" reply
  $ASSUME_YES && return 0
  if [[ ! -t 0 ]]; then
    echo "Refusing to assume consent with no terminal attached." >&2
    echo "Re-run interactively, or pass --assume-yes if you accept the above." >&2
    return 1
  fi
  read -r -p "$prompt [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# Copy a repo config into place, but only when it actually differs, and always
# back up what was there first. Used for every file this script overwrites, so
# nothing in your home directory is replaced without a recoverable copy.
install_config() {
  local src="$1" dest="$2" name backup
  name="$(basename "$dest")"
  if cmp -s "$src" "$dest" 2>/dev/null; then
    log "$name already up to date"
    return 0
  fi
  if [[ -e "$dest" ]]; then
    backup="${dest}.backup.$(date +%s 2>/dev/null || echo old)"
    log "Backing up existing $name -> $backup"
    cp "$dest" "$backup"
  fi
  log "Installing $name"
  cp "$src" "$dest"
}

# --- 1. Homebrew ------------------------------------------------------------
BREW_INSTALLER_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
if ! command -v brew >/dev/null 2>&1; then
  log "Homebrew is not installed"
  cat <<EOF

  This will download a remote script and execute it as your user:

      $BREW_INSTALLER_URL

  That is Homebrew's official installer, and it is fetched from HEAD, so its
  contents can change between runs. It will ask for your password (sudo) to
  create the Homebrew prefix.

  To review it first, in another terminal:
      curl -fsSL $BREW_INSTALLER_URL | less

  Or install Homebrew yourself from https://brew.sh and re-run this script,
  which will then skip this step entirely.

EOF
  if ! confirm "  Download and run the Homebrew installer now?"; then
    echo "Aborted. Install Homebrew yourself and re-run this script." >&2
    exit 1
  fi
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL "$BREW_INSTALLER_URL")"
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
# Pinned to a tag and verified against a known commit, rather than tracking the
# default branch, so a compromised or simply changed upstream cannot silently
# alter what runs on your machine.
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  log "Cloning TPM $TPM_VERSION"
  git clone --branch "$TPM_VERSION" --depth 1 \
      https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  ACTUAL_COMMIT="$(git -C "$HOME/.tmux/plugins/tpm" rev-parse HEAD)"
  if [[ "$ACTUAL_COMMIT" != "$TPM_COMMIT" ]]; then
    echo "TPM commit mismatch for tag $TPM_VERSION." >&2
    echo "  expected: $TPM_COMMIT" >&2
    echo "  actual:   $ACTUAL_COMMIT" >&2
    echo "The tag may have been moved upstream. Refusing to continue." >&2
    rm -rf "$HOME/.tmux/plugins/tpm"
    exit 1
  fi
  log "TPM pinned at $TPM_VERSION ($TPM_COMMIT)"
else
  log "TPM already present at $(git -C "$HOME/.tmux/plugins/tpm" rev-parse --short HEAD 2>/dev/null || echo 'unknown revision')"
fi

# --- 4. tmux config ---------------------------------------------------------
install_config "$SCRIPT_DIR/config/tmux.conf" "$HOME/.tmux.conf"

# --- 5. Install plugins (headless) -----------------------------------------
# PID-based session name so we cannot collide with a real user session, and an
# EXIT trap so `set -e` bailing out of install_plugins still cleans it up.
# Note: TPM fetches each plugin from its own default branch, unpinned. Pinning
# TPM does not pin the plugins it pulls. See the README "What this fetches".
log "Installing tmux plugins (fetched unpinned from their default branches)"
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
install_config "$SCRIPT_DIR/config/claude-proj.zsh" "$HOME/.claude-proj.zsh"
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
