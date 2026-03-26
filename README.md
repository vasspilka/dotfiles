# Dotfiles

Personal cross-platform dotfiles (macOS primary, Linux supported). Everything is symlinked to `~` via `install.sh`.

## Quick Start

```bash
# Link dotfiles only
./install.sh

# Fresh machine — install dependencies first
./install.sh --with-deps
```

`--with-deps` installs: Homebrew (mac), Oh My Zsh, Antigen, Starship, mise, fzf.

After linking, restart your shell or `source ~/.zshrc`.

## What's Included

| File / Dir | Purpose |
|---|---|
| `.zshrc` | Zsh config — platform detection, PATH, plugins (Antigen), aliases |
| `.config/starship.toml` | Starship prompt (right-aligned clock) |
| `.config/alacritty/` | Alacritty terminal config |
| `.doom.d/` | Doom Emacs (init, packages, config) |
| `.tmux.conf` | tmux — `C-a` prefix, vi copy mode, TPM plugins |
| `.gitconfig` | Git — LFS, nvim editor, aliases (`lg`, `c`, `p`) |
| `.tool-versions` | mise-managed runtimes (erlang, elixir, rust, node, python, ruby) |
| `.vimrc` | Vim/Neovim base config |
| `.gitignore_global` | Global gitignore |
| `install.sh` | Idempotent installer with platform detection |

## Shell Aliases

**Elixir/Phoenix** — `mt` (test), `ms` (server), `mxs` (iex server), `mck` (format+credo+dialyzer+test), `ashremigrate`

**Git** — `gamend`, `gitdeletemerged`

**Tools** — `dk`/`dkc` (docker), `c` (claude), `e` (emacs -nw)

## Secrets

Machine-local config goes in `~/.zprofile` — sourced by `.zshrc` but never symlinked or committed.
