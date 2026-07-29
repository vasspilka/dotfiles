# Dotfiles

Personal cross-platform dotfiles (macOS primary, Linux supported). Everything is symlinked to `~` via `install.sh`.

## Quick Start

```bash
# Link dotfiles only
./install.sh

# Fresh machine — install dependencies first
./install.sh --with-deps
```

`--with-deps` installs: Homebrew (mac), Oh My Zsh, Antigen, Starship, mise, fzf, jq, RTK, TPM, GitHub CLI, Git LFS, Podman, socat.

The GitHub CLI is not optional: `.gitconfig` delegates GitHub credentials to `gh auth git-credential`, so `git push` to GitHub fails without it. Git LFS is likewise required: `.gitconfig` marks the LFS filter as `required = true`, so git operations in LFS repos fail without it.

After linking, restart your shell or `source ~/.zshrc`.

## What's Included

| File / Dir | Purpose |
|---|---|
| `.zshrc` | Zsh config — platform detection, PATH, plugins (Antigen), aliases |
| `.config/starship.toml` | Starship prompt (right-aligned clock) |
| `.config/cship.toml` | Claude Code statusline config |
| `.config/alacritty/` | Alacritty terminal config |
| `.tmux.conf` | tmux — `C-a` prefix, vi copy mode, TPM plugins |
| `.gitconfig` | Git — LFS, nvim editor, aliases (`lg`, `c`, `p`) |
| `.tool-versions` | mise-managed runtimes (erlang, elixir, rust, node, python, ruby) |
| `.vimrc` | Vim/Neovim base config |
| `.gitignore_global` | Global gitignore |
| `.claude/` | Claude Code config — global instructions, settings, keybindings, hooks, skills |
| `.gemini/` | Gemini CLI config — settings (MCP servers) |
| `.pi/agent/` | Pi config — settings, shared global instructions, extensions |
| `tools/sandbox/` | Podman-based development sandbox CLI (`sandbox` shell command; see `tools/sandbox/README.md`) |
| `install.sh` | Idempotent installer with platform detection |

## Shell Aliases

**Elixir/Phoenix** — `mt` (test), `ms` (server), `mxs` (iex server), `mck` (format+credo+dialyzer+test), `ashremigrate`

**Git** — `gamend`, `gitdeletemerged`

**Tools** — `dk`/`dkc` (docker), `cc` (claude), `e` (nvim), `sandbox` (Podman dev sandbox)

## Development Sandbox

```bash
sandbox build              # build with cache
sandbox build --fresh      # rebuild without cache
sandbox build --update-agents  # refresh just the agent CLIs
sandbox                    # start/reuse sandbox for current project and open bash
sandbox ~/Work/my-app      # same, for another project path
sandbox exec mix test      # run one command in the sandbox, propagates exit status
sandbox recreate --port 4000   # recreate and publish a port on localhost
sandbox recreate --no-network  # recreate with network egress cut off
sandbox list               # list sandboxes: staleness, network, ports, auth mode, project
sandbox expose 4000        # relay a port without restarting (slower fallback)
sandbox stop               # stop the current project's sandbox
sandbox stop --all         # stop every running sandbox
sandbox rm                 # remove current project's sandbox AND its volumes (asks first)
sandbox prune              # remove stopped containers; volumes are kept while their project exists
sandbox clean              # remove EVERYTHING incl. volumes (asks first)
```

Each project path gets its own `sbx-<hash>` container. The project is mounted at `/workspace`, while `_build`, `deps`, mise installs, and agent state are kept in persistent per-project Podman volumes.

The only host paths a sandbox can see are the project itself plus read-only `~/.gitconfig` and `~/.gitignore_global`. Host agent auth directories are not mounted — each sandbox signs in separately, so `git push` needs `gh auth login` inside the box on first use. Use `sandbox --host-auth` only for trusted repositories.

`install.sh` links `sandbox` into `~/.local/bin`, so it works from scripts and non-zsh shells too.

Run `tools/sandbox/test.sh` to validate the sandbox CLI without starting a container. See `tools/sandbox/README.md` for the full reference and `tools/sandbox/ALTERNATIVES.md` for researched open-source alternatives and future direction.

## Secrets

Machine-local config goes in `~/.zprofile` — sourced by `.zshrc` but never symlinked or committed.

Claude Code/Pi auth, sessions, caches, histories, and other runtime state are intentionally not synced (for example `~/.claude.json`, `~/.pi/agent/auth.json`, and session directories).
