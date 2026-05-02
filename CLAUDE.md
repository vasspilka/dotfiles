# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal cross-platform dotfiles (macOS primary, Linux supported). Config files are symlinked from this repo to `~` via `install.sh`.

## Installation

```bash
# Link dotfiles only (idempotent — skips already-correct symlinks)
./install.sh

# Fresh machine — install all dependencies first
./install.sh --with-deps
```

The script detects macOS vs Linux, symlinks top-level dotfiles, `.config/`, `.claude/`, and `.pi/agent/` config individually (preserving runtime/auth data), and creates `~/.zprofile` if missing.

## File Map

| File / Dir | What it configures |
|---|---|
| `.zshrc` | Shell — platform detection, PATH, Antigen plugins, aliases |
| `.config/starship.toml` | Starship prompt (right-aligned clock) |
| `.config/cship.toml` | Claude Code statusline |
| `.config/alacritty/` | Alacritty terminal |
| `.tmux.conf` | tmux — `C-a` prefix, vi copy mode, TPM plugins (resurrect, continuum, yank, open) |
| `.gitconfig` | Git — LFS, nvim editor, `autoSetupRemote`, aliases |
| `.tool-versions` | mise runtimes: erlang, elixir, rust, nodejs, python, ruby |
| `.vimrc` | Vim/Neovim base config |
| `.gitignore_global` | Global gitignore patterns |
| `.claude/` | Claude Code — global CLAUDE.md, settings, keybindings, hooks (RTK), skills |
| `.pi/agent/` | Pi — settings, global AGENTS.md linked to Claude instructions, extensions |
| `install.sh` | Installer — platform detection, dependency install, symlink management |

## Key Conventions

- Primary dev stack is **Elixir/Phoenix** — most aliases target this (`mt`, `mxs`, `mck`, `ashremigrate`)
- **Antigen** manages all zsh plugins — do not use the `plugins=()` array, add `antigen bundle` lines instead
- **mise** manages `.tool-versions` — not asdf
- **tmux plugins** managed by TPM — install new plugins with `prefix + I`
- `~/.zprofile` holds secrets and machine-local config — sourced by `.zshrc` but never symlinked or committed
- Claude Code/Pi auth, sessions, caches, and histories stay local; do not sync `~/.claude.json`, `~/.pi/agent/auth.json`, or session directories
- Platform-specific code uses `IS_MAC` / `IS_LINUX` guards (set in `.zshrc`) or `PLATFORM` (set in `install.sh`)
- `install.sh` is idempotent — safe to re-run; skips already-correct symlinks and already-installed tools
- Git aliases: `lg` (graph log), `c` (commit -m), `p` (push)
- Shell alias `cc` launches Claude Code
