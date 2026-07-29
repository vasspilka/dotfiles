#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect platform
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="mac" ;;
  Linux)  PLATFORM="linux" ;;
  *)      echo "Unsupported OS: $OS"; exit 1 ;;
esac

echo "Detected platform: $PLATFORM"

install_prerequisites() {
  echo ""
  echo "=== Installing prerequisites ==="

  # Homebrew (Mac) or essential packages (Linux)
  if [ "$PLATFORM" = "mac" ]; then
    if ! command -v brew &>/dev/null; then
      echo "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      echo "Homebrew already installed"
    fi
  fi

  # Oh My Zsh
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  else
    echo "Oh My Zsh already installed"
  fi

  # Antigen
  if [ ! -f "$HOME/antigen.zsh" ]; then
    echo "Installing Antigen..."
    curl -L https://raw.githubusercontent.com/zsh-users/antigen/master/bin/antigen.zsh > ~/antigen.zsh
  else
    echo "Antigen already installed"
  fi

  # Starship prompt
  if ! command -v starship &>/dev/null; then
    echo "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh
  else
    echo "Starship already installed"
  fi

  # mise (version manager)
  if ! command -v mise &>/dev/null; then
    echo "Installing mise..."
    curl https://mise.run | sh
  else
    echo "mise already installed"
  fi

  # fzf
  if ! command -v fzf &>/dev/null; then
    echo "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
  else
    echo "fzf already installed"
  fi

  # jq (required by RTK hook)
  if ! command -v jq &>/dev/null; then
    echo "Installing jq..."
    if [ "$PLATFORM" = "mac" ]; then
      brew install jq
    else
      sudo apt-get install -y jq 2>/dev/null || sudo pacman -S --noconfirm jq 2>/dev/null
    fi
  else
    echo "jq already installed"
  fi

  # RTK (token-optimized CLI proxy for Claude Code)
  if ! command -v rtk &>/dev/null; then
    echo "Installing RTK..."
    if [ "$PLATFORM" = "mac" ]; then
      brew install rtk
    else
      cargo install rtk
    fi
  else
    echo "RTK already installed"
  fi

  # TPM (Tmux Plugin Manager)
  if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    echo "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  else
    echo "TPM already installed"
  fi

  # GitHub CLI. .gitconfig clears any inherited credential helper and delegates
  # GitHub/Gist credentials to 'gh auth git-credential', so without gh on PATH
  # every push to GitHub fails with an error that does not mention gh at all.
  install_github_cli ||
    echo "Warning: gh missing — .gitconfig delegates GitHub credentials to it, so pushes will fail." >&2

  # Git LFS. .gitconfig marks the LFS filter as required=true, so git operations
  # in LFS repos hard-fail without the binary. Same story as gh: the sandbox
  # image installs it too, because the sandbox mounts that same .gitconfig.
  install_package git-lfs ||
    echo "Warning: git-lfs missing — .gitconfig requires the LFS filter, so LFS repos will fail." >&2

  # Podman (required by sandbox tool) and socat (required by 'sandbox expose').
  # Failures are reported rather than swallowed: a silently missing Podman turns
  # into a confusing error the first time someone runs 'sandbox'.
  # These are only needed by the sandbox tool, so a failure is reported loudly
  # but does not abort linking the rest of the dotfiles.
  install_package podman ||
    echo "Warning: Podman missing — the 'sandbox' command will not work." >&2
  install_package socat ||
    echo "Warning: socat missing — 'sandbox expose' will not work." >&2

  if [ "$PLATFORM" = "mac" ] && command -v podman &>/dev/null; then
    if ! podman machine list --format '{{.Name}}' 2>/dev/null | grep -q .; then
      # The machine's default 2 GB of RAM cannot honor the sandbox's default
      # 8g container ceiling, and compiling Erlang from source (the first
      # thing a new Elixir sandbox does) can OOM inside it. Size the VM to
      # 8 GB / 4 CPUs, clamped to half the host so small machines still work.
      local vm_memory vm_cpus host_mb host_cpus
      vm_memory=8192
      host_mb=$(($(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1048576))
      if [ "$host_mb" -gt 0 ] && [ $((host_mb / 2)) -lt "$vm_memory" ]; then
        vm_memory=$((host_mb / 2))
      fi
      vm_cpus=4
      host_cpus="$(sysctl -n hw.ncpu 2>/dev/null || echo 0)"
      if [ "$host_cpus" -gt 0 ] && [ $((host_cpus / 2)) -lt "$vm_cpus" ]; then
        vm_cpus=$((host_cpus / 2))
      fi
      if [ "$vm_cpus" -lt 1 ]; then
        vm_cpus=1
      fi

      echo "Initializing Podman machine (${vm_memory} MB RAM, ${vm_cpus} CPUs)..."
      echo "  Note: this downloads a VM image (~1 GB) and may take several minutes."
      podman machine init --memory "$vm_memory" --cpus "$vm_cpus" ||
        echo "Warning: 'podman machine init' failed; run it manually." >&2
    fi

    if ! podman info &>/dev/null; then
      echo "Starting Podman machine..."
      podman machine start ||
        echo "Warning: 'podman machine start' failed; run it manually." >&2
    else
      echo "Podman machine already running"
    fi
  fi
}

# The GitHub CLI needs its own installer: the binary is 'gh', but the package is
# named 'github-cli' on Arch, and Debian/Ubuntu carry no usable version at all,
# so its apt repository has to be added first (same approach as the sandbox image).
install_github_cli() {
  if command -v gh &>/dev/null; then
    echo "gh already installed"
    return 0
  fi

  echo "Installing GitHub CLI..."

  if [ "$PLATFORM" = "mac" ]; then
    brew install gh || {
      echo "Error: 'brew install gh' failed." >&2
      return 1
    }
    return 0
  fi

  if command -v apt-get &>/dev/null; then
    if ! {
      sudo mkdir -p -m 755 /etc/apt/keyrings &&
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
          sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null &&
        sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg &&
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
          sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null &&
        sudo apt-get update && sudo apt-get install -y gh
    }; then
      echo "Error: installing gh from the GitHub CLI apt repository failed." >&2
      return 1
    fi
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm github-cli || {
      echo "Error: 'pacman -S github-cli' failed." >&2
      return 1
    }
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y gh || {
      echo "Error: 'dnf install gh' failed." >&2
      return 1
    }
  else
    echo "Error: No supported package manager found (apt-get, pacman, dnf)." >&2
    echo "Install the GitHub CLI manually, then re-run this script." >&2
    return 1
  fi
}

# Installs a package with the platform's package manager, reporting the real
# error on failure instead of discarding it.
install_package() {
  local package="$1"

  if command -v "$package" &>/dev/null; then
    echo "$package already installed"
    return 0
  fi

  echo "Installing $package..."

  if [ "$PLATFORM" = "mac" ]; then
    brew install "$package" || {
      echo "Error: 'brew install $package' failed." >&2
      return 1
    }
    return 0
  fi

  if command -v apt-get &>/dev/null; then
    if ! { sudo apt-get update && sudo apt-get install -y "$package"; }; then
      echo "Error: 'apt-get install $package' failed." >&2
      return 1
    fi
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm "$package" || {
      echo "Error: 'pacman -S $package' failed." >&2
      return 1
    }
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y "$package" || {
      echo "Error: 'dnf install $package' failed." >&2
      return 1
    }
  else
    echo "Error: No supported package manager found (apt-get, pacman, dnf)." >&2
    echo "Install '$package' manually, then re-run this script." >&2
    return 1
  fi
}

link_path() {
  local source="$1"
  local target="$2"
  local label="$3"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    echo "  already linked: $label"
  else
    rm -rf "$target"
    ln -v -s "$source" "$target"
  fi
}

link_dir_children() {
  local source_dir="$1"
  local target_dir="$2"
  local label_prefix="$3"

  [ -d "$source_dir" ] || return
  mkdir -p "$target_dir"

  local item name
  for item in "$source_dir"/*; do
    [ -e "$item" ] || [ -L "$item" ] || continue
    name="$(basename "$item")"
    link_path "$item" "$target_dir/$name" "$label_prefix/$name"
  done
}

link_dotfiles() {
  echo ""
  echo "=== Linking dotfiles ==="

  # Link top-level dotfiles (exclude directories handled specially below)
  local item file name
  for item in "$DOTFILES_DIR"/.[!.]*; do
    [ -e "$item" ] || [ -L "$item" ] || continue
    file="$(basename "$item")"

    case "$file" in
      .git|.gitignore|.gitmodules|.DS_Store|.config|.claude|.gemini|.pi)
        continue
        ;;
    esac

    link_path "$item" "$HOME/$file" "$file"
  done

  # Link .config/ children individually (preserves other .config contents)
  link_dir_children "$DOTFILES_DIR/.config" "$HOME/.config" ".config"

  # Link .claude/ children individually (preserves runtime data like cache, sessions, etc.)
  link_dir_children "$DOTFILES_DIR/.claude" "$HOME/.claude" ".claude"

  # Link .gemini/ children individually (preserves oauth_creds.json and other runtime state)
  link_dir_children "$DOTFILES_DIR/.gemini" "$HOME/.gemini" ".gemini"

  # Link Pi config while preserving auth.json, sessions, and local-only runtime state.
  if [ -d "$DOTFILES_DIR/.pi/agent" ]; then
    mkdir -p "$HOME/.pi/agent"

    for item in "$DOTFILES_DIR"/.pi/agent/*; do
      [ -e "$item" ] || [ -L "$item" ] || continue
      name="$(basename "$item")"

      case "$name" in
        extensions)
          link_dir_children "$item" "$HOME/.pi/agent/extensions" ".pi/agent/extensions"
          ;;
        *)
          link_path "$item" "$HOME/.pi/agent/$name" ".pi/agent/$name"
          ;;
      esac
    done
  fi

  link_tools
}

# Executable tools go on PATH rather than being wrapped in a zsh function, so
# they also work from scripts, non-interactive shells, and other shells.
# ~/.local/bin is already prepended to PATH in .zshrc.
link_tools() {
  mkdir -p "$HOME/.local/bin"
  link_path "$DOTFILES_DIR/tools/sandbox/sandbox.sh" "$HOME/.local/bin/sandbox" "bin/sandbox"
}

setup_zprofile() {
  # Create .zprofile if it doesn't exist (holds secrets, never symlinked)
  if [ ! -f "$HOME/.zprofile" ]; then
    echo ""
    echo "=== Creating empty .zprofile ==="
    touch "$HOME/.zprofile"
    echo "  created ~/.zprofile (add your secrets/local config here)"
  fi
}

# --- Main ---

echo "Dotfiles installer ($PLATFORM)"
echo "=============================="

if [ "${1}" = "--with-deps" ]; then
  install_prerequisites
fi

link_dotfiles
setup_zprofile

echo ""
echo "Done! Run with --with-deps to install prerequisites (oh-my-zsh, antigen, starship, mise, fzf, jq, rtk, tpm, gh, git-lfs, podman, socat)."
echo "Claude Code and Pi configs are linked; auth, sessions, caches, and other runtime state stay local."
echo "Restart your shell or run: source ~/.zshrc"
