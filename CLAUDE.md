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
| `.gemini/` | Gemini CLI — settings (MCP servers); linked per-child to preserve auth |
| `.pi/agent/` | Pi — settings, global AGENTS.md linked to Claude instructions, extensions |
| `tools/sandbox/` | Podman dev-sandbox CLI (`sandbox` shell command) — see `tools/sandbox/README.md` |
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
- **Sandbox defaults to isolated agent auth** — host `~/.claude`, `~/.gemini`, `~/.pi` are never mounted unless `--host-auth` is passed, which is only for trusted repos. Mount/network/port options apply at container creation only; changing them needs `sandbox recreate`
- **A sandbox sees only the project plus read-only `~/.gitconfig` and `~/.gitignore_global`** — never mount the dotfiles repo to share config with it; stream files in via `podman exec` (see `seed_agent_config`) so the promise stays a short list
- **`npx @scope/package` does not resolve a global install** — npm exec looks for a bin named exactly `@scope/package`, finds none, and fetches from the registry. `seed_agent_config` rewrites seeded MCP servers to the real bin (`@playwright/mcp` → `playwright-mcp`) so they work under `--network none` and cannot drift from the pinned image; do not simplify that back to a verbatim copy
- **A sandbox that fails to initialize is removed, not left running** (see `abort_partial_start`) — a surviving half-initialized container has root-owned volumes and no toolchain, yet makes every later command report "already running" and hand back a broken shell
- **Seeded `.claude/settings.json` is filtered by an allowlist, not a denylist** (`SEED_CLAUDE_SETTINGS_KEYS`) — `hooks` and `statusLine` invoke host-only binaries (`rtk`, `cship`) and would fail on every tool call inside a sandbox. A denylist would mean the next host-specific key added upstream silently breaks every sandbox; when in doubt a key stays out. `CLAUDE.md` is seeded with `@import` lines dropped when their target was not seeded, so no import ever dangles
- **Seeding copies only what is absent, never overwrites** — in-sandbox edits survive restarts, yet a skill added upstream still arrives on the next `start` or `shell`: seeding runs on every start *and* on `shell` into a running container (bare `sandbox` is the primary entry point, so it must keep the same promise), and for an existing container it is guarded by the `sandbox.host-auth` *label*, never the current flags — a `--host-auth` container's `~/.claude` is the real host directory. Pack the tar with `COPYFILE_DISABLE=1`: macOS bsdtar otherwise ships xattrs as AppleDouble `._name` members that GNU tar in the container extracts as real files
- **Podman's `volume create` is not idempotent like Docker's** — it fails on an existing name, and sandbox volumes deliberately outlive their container (`recreate`, `prune`, failed init all keep them), so `create_volume` checks `podman volume exists` first. The test stub models the real failure; do not "simplify" either side
- **`prune` decides volume orphanhood by the `sandbox.project` volume label, never by references** — prune itself removes stopped containers, so "referenced by no container" would delete on the *second* prune the caches and agent state the first one promised to keep. A volume is removed only when its labeled project directory is gone; unlabeled volumes are never pruned (`clean` takes those)
- **`sandbox rm` matches volumes by name prefix but deletes only label-verified ones** — a volume whose `sandbox.project` label names another project (hash collision) is reported and kept. `rm` is the per-project reset between `stop` (keeps everything) and `clean` (removes every project's state)
- **devcontainer.json is JSONC in the wild** — VS Code templates ship comments and trailing commas that strict `jq` rejects. `strip_jsonc` normalizes character by character (string-aware, so `//` inside a `$schema` URL survives) and the result is used only after `jq` validates it; on failure the CLI reports it, ports fall back to grep recovery, mounts never do
- **`exec` deliberately does not re-seed a running sandbox** — it is the scripted fast path, and two extra `podman exec`s per command is real overhead in a loop; `start` and `shell` keep the seeding promise
- **Every port the container publishes goes on the `sandbox.ports` label** — `--port` and devcontainer `forwardPorts` are one deduped list computed before the run args (`effective_ports`), because a published port missing from the label is invisible to `sandbox list` and to drift detection, and publishing one twice makes Podman fail outright
- `.gitconfig` delegates GitHub credentials to `gh auth git-credential` and marks the Git LFS filter `required = true`, so `gh` and `git-lfs` are hard dependencies on the host *and* in the sandbox image — keep both installers in sync
- The sandbox image compiles Erlang from source via mise/kerl — `autoconf`, `m4`, and `libncurses-dev` are load-bearing in the Dockerfile, not incidental
- Executable tools live in `tools/` and are symlinked into `~/.local/bin` by `install.sh` — do not wrap them in zsh functions, that breaks them in scripts and non-zsh shells
