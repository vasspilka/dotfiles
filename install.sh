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
}

link_dotfiles() {
  echo ""
  echo "=== Linking dotfiles ==="

  # Link top-level dotfiles (exclude .git, .DS_Store, .config, .gitmodules)
  for file in $(ls -A "$DOTFILES_DIR" | grep "^\.[a-z]" | grep -v "^\.git$" | grep -v "^\.gitignore$" | grep -v "^\.gitmodules$" | grep -v "\.DS_Store" | grep -v "\.config" | grep -v "\.claude"); do
    target="$HOME/$file"
    source="$DOTFILES_DIR/$file"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      echo "  already linked: $file"
    else
      rm -f "$target"
      ln -v -s "$source" "$target"
    fi
  done

  # Link .config/ children individually (preserves other .config contents)
  mkdir -p "$HOME/.config"
  for item in "$DOTFILES_DIR"/.config/*; do
    name="$(basename "$item")"
    target="$HOME/.config/$name"
    source="$item"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      echo "  already linked: .config/$name"
    else
      rm -f "$target"
      ln -v -s "$source" "$target"
    fi
  done

  # Link .claude/ children individually (preserves runtime data like cache, sessions, etc.)
  mkdir -p "$HOME/.claude"
  for item in "$DOTFILES_DIR"/.claude/*; do
    name="$(basename "$item")"
    target="$HOME/.claude/$name"
    source="$item"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      echo "  already linked: .claude/$name"
    else
      rm -rf "$target"
      ln -v -s "$source" "$target"
    fi
  done
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
echo "Done! Run with --with-deps to install prerequisites (oh-my-zsh, antigen, starship, mise, fzf, jq, rtk, tpm)."
echo "Restart your shell or run: source ~/.zshrc"
