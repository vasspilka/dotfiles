# Sandbox CLI

Podman-based development sandboxes for project work.

The goal is a small local wrapper for interactive coding-agent work, not a full sandbox platform. See [`ALTERNATIVES.md`](./ALTERNATIVES.md) for researched open-source alternatives and future direction.

## Commands

| Command | What it does |
|---|---|
| `sandbox build` | Builds the sandbox image using Podman's cache |
| `sandbox build --fresh` | Rebuilds without cache |
| `sandbox build --update-agents` | Rebuilds only the layer holding the agent CLIs, picking up their latest releases |
| `sandbox build --dns 8.8.8.8` | Builds with a custom DNS server when troubleshooting networking |
| `sandbox` / `sandbox shell [path]` / `sandbox <path>` | Starts/reuses the project sandbox and opens Bash |
| `sandbox start [path]` | Starts/reuses the project sandbox without opening a shell |
| `sandbox exec [-C path] [--create] <cmd>` | Runs one command in the sandbox and returns its exit status; starts a stopped sandbox but refuses to build a missing one unless `--create` is given |
| `sandbox recreate [path]` | Recreates the project container after an image rebuild or an option change; preserves named volumes |
| `sandbox start --recreate [path]` | Same recreation behavior via `start` |
| `sandbox list` | Lists sandbox containers with state, staleness, network mode, published ports, auth mode, and project path |
| `sandbox expose <port> [path]` | Relays a running sandbox's port to `localhost:<port>` without restarting |
| `sandbox stop [--all] [path]` | Stops the project sandbox; `--all` stops every running sandbox |
| `sandbox rm [--force] [path]` | Removes the project's sandbox container **and** its volumes — build caches and agent state — after confirmation; volumes whose label names another project (hash collision) are reported and kept |
| `sandbox prune` | Removes stopped (and created-but-never-started) sandbox containers, plus volumes whose recorded project directory no longer exists — a volume whose project still exists is always kept, so prune is safe to repeat |
| `sandbox clean [--force]` | Stops and removes ALL sandbox containers and volumes, including agent state; asks for confirmation (`--force` skips it) |

`--help` works on every subcommand and always exits `0` without touching any container. Subcommands reject arguments they cannot act on rather than ignoring them, so `sandbox stop --port 4000` is an error instead of a silent no-op.

## Running commands non-interactively

`sandbox exec` is the scriptable entry point — useful from a Makefile, from CI, or from an agent driving the sandbox from the host:

```bash
sandbox exec mix test                    # current directory's sandbox
sandbox exec -C ~/Work/my-app mix test   # another project
sandbox exec -- ls -la                   # -- ends option parsing
```

The command runs through a login Bash so mise shims resolve, arguments keep their quoting, and the command's exit status is propagated. If the sandbox exists but is stopped, it is started first. A sandbox that does not exist yet is never built implicitly — a typo'd `-C` path would otherwise spend minutes creating a fresh sandbox only to run the command in an empty workspace. Pass `--create` to allow building one.

Unlike `start` and `shell`, `exec` does not re-seed agent config into an already-running sandbox: it is the fast path for scripted loops, and two extra `podman exec`s per command would be real overhead there. Config added upstream still lands on the next `start` or `shell`.

`sandbox rm` completes the lifecycle between `stop` (keeps everything) and `clean` (removes every project's state): it removes one project's container and volumes — the reset for a corrupted `_build` volume or a botched toolchain, without hand-typing generated volume names. It asks for confirmation (`--force` skips it, and is required non-interactively), and it never touches a volume whose `sandbox.project` label names a different project.

## Options for `start` / `shell` / `recreate`

| Option | Effect |
|---|---|
| `--port N` | Publishes container port `N` on `127.0.0.1:N`. Repeatable. |
| `--network MODE` | Podman network mode: `none`, `bridge`, `slirp4netns`, `pasta`, `host`. |
| `--no-network` | Shorthand for `--network none`. |
| `--host-auth` | Mounts host agent auth/config instead of using isolated volumes. Risky. |
| `--recreate` | Replaces an existing container; preserves volumes. |

These are all fixed at container creation. Explicitly asking for different values on an existing sandbox — by flag or `SANDBOX_*` variable — prints a drift warning and points you at `sandbox recreate`. Options you did not ask for stay as they were, silently: a plain `sandbox` after `recreate --port 4000` keeps the port and does not nag.

## Runtime model

```text
Host project path
  → hashed into container name: sbx-<hash>
  → recorded in full on the sandbox.project label
  → mounted at /workspace
  → paired with persistent Podman volumes:
      /workspace/_build
      /workspace/deps
      /home/developer/.local/share/mise
      /home/developer/.claude
      /home/developer/.gemini
      /home/developer/.pi
```

The container name is a truncated hash, so two project paths could in principle produce the same name. The full path is stored on the `sandbox.project` label and verified before any container is reused — a collision is refused with an error instead of silently sharing another project's workspace and caches. Volumes carry the same `sandbox.project` label: reusing a collided volume is refused the same way, and `prune` uses the label to tell a volume whose project still exists (kept for the next start) from a true orphan whose project directory is gone. Prune removes only the latter — "referenced by no container" is not enough, because prune itself removes stopped containers, and their volumes must survive the *next* prune too. Volumes created before labeling existed are never pruned; `clean` removes those.

The image runs commands as a non-root `developer` user. Root is used only during image build and for a startup ownership fix on named volumes.

Containers run with `--init` (so exec'd shells don't leak zombie processes) and carry `sandbox.project`, `sandbox.host-auth`, `sandbox.network`, and `sandbox.ports` labels. The labels power `sandbox list` and drift detection.

New containers get generous resource ceilings — `--memory 8g` and `--pids-limit 4096` — so a runaway agent or a fork-bombing build cannot starve the host. Override with `SANDBOX_MEMORY` / `SANDBOX_PIDS_LIMIT`; setting one to `0` drops that limit (useful on hosts without the memory cgroup controller). Like all creation-time options, changes apply on the next `sandbox recreate`.

On Linux, containers run with `--userns=keep-id:uid=1000,gid=1000` so the bind-mounted `/workspace` stays writable for the in-container user under rootless Podman. macOS handles this via the Podman machine.

If `mise install` fails on first start, the sandbox still starts and you get a warning. Open a shell and re-run `mise install` to see the full error. This is a safety net, not the expected path — see below.

Failures *earlier* than that are treated the opposite way. If the container never becomes ready, or the volume ownership fix fails, the half-initialized container is removed instead of being left running — otherwise the next `sandbox` would find it, report "already running", and hand back a shell into a box with root-owned build volumes and no toolchain. Named volumes are kept, exactly as in `recreate`, so a retry reuses any cache the failed attempt produced.

## Image toolchain

The image carries the build dependencies `.tool-versions` actually needs, because mise compiles Erlang from source via kerl:

```text
autoconf, m4, libncurses-dev   OTP configure aborts without these
libssl-dev, zlib1g-dev         crypto and compression
pkg-config, unzip              general build + Elixir/Hex archives
inotify-tools                  Phoenix live reload file watching
build-essential                compiler toolchain
```

Without `libncurses-dev` in particular, OTP's `configure` fails with "No curses library functions found" and the first `sandbox` in a Phoenix project lands straight in the `mise install` warning path above.

Playwright is pinned via `PLAYWRIGHT_VERSION` (currently `1.62.0`) because the npm packages must match the browsers baked into the base image. Bump the ARG to move both together; confirm the matching `mcr.microsoft.com/playwright:v<version>-jammy` tag exists first.

The image deliberately carries no prebuilt language runtimes: the first `sandbox` in a project compiles whatever `.tool-versions` pins (Erlang from source takes the longest), and the per-project mise volume caches the result for every start after that. The trade was weighed the other way too — Podman copies image content into a fresh named volume on first mount, so baking the toolchain into the image would make first starts fast — but at the cost of a much larger image that is specific to one stack and goes stale with every version bump. If first-start latency starts to hurt, that copy-up behavior is the lever to revisit.

## Ports

Prefer publishing at creation time:

```bash
sandbox recreate --port 4000
```

That maps `127.0.0.1:4000` straight through to the container. `sandbox expose 4000` exists for when you cannot restart the sandbox:

```text
Browser on host
  → http://localhost:4000
  → socat on host
  → podman exec <sandbox> nc localhost 4000
  → app inside sandbox
```

Each inbound connection spawns a `podman exec`, which is noticeably slower for connection-heavy apps (a LiveView socket plus dozens of asset requests). Use `--port` when you can.

Ports must be numeric and within `1..65535`. Both mechanisms bind to `127.0.0.1` only, so exposed apps are not reachable from the local network.

## Auth and host mounts

By default, host agent auth/config directories are **not** mounted. Each project gets isolated named volumes for Claude, Gemini, and Pi state. This means you may need to sign in inside each sandbox, but untrusted project code cannot directly read your host auth directories.

Exactly two host paths are mounted, both read-only, both only when present:

```text
~/.gitconfig         → /home/developer/.gitconfig:ro
~/.gitignore_global  → /home/developer/.gitignore_global:ro
```

That is the whole list. Shared agent config is *streamed* in rather than mounted — piped through `podman exec` into the isolated volumes on every `sandbox start` and on every `sandbox shell` into an already-running container (a sandbox created with `--host-auth` is never seeded — the CLI checks the container's label, since its `~/.claude` is the real host directory):

```text
.gemini/settings.json  → ~/.gemini/settings.json    (MCP servers, rewritten — see below)
.claude/CLAUDE.md      → ~/.claude/CLAUDE.md        (@imports of unseeded files dropped)
.claude/skills/        → ~/.claude/skills/
.claude/settings.json  → ~/.claude/settings.json    (filtered to an allowlist)
```

Existing files are never overwritten, so in-sandbox edits survive restarts — but anything *added* upstream still lands on the next start or shell, so a new skill is one `sandbox` away rather than needing a `recreate`. A failed seed warns and prints the payload's own error, since the scripts run inside the container and their output is the only diagnostic there is.

An earlier version bind-mounted the entire dotfiles repo read-only to copy one file. That leaked far more than it needed to — the repo carries `.claude/` settings, hooks, and skills, and the mount also told every sandbox the host path they live at. Streaming keeps the rule short enough to hold in your head: **a sandbox sees your project, and your two git config files.**

On the way in, MCP servers launched through `npx` are rewritten to the binaries the image already installs: `npx -y @playwright/mcp` becomes `playwright-mcp`. This is not cosmetic. `npm exec` searches the global bin directory for a file named exactly `@playwright/mcp`, never finds one — the package's bin is `playwright-mcp` — and falls through to a registry manifest fetch on every launch. That fails outright under `--network none`, and otherwise pulls whatever version is newest, which can drift from the Playwright browsers pinned into the image. The host copy of the same file keeps using `npx`, since nothing is preinstalled there.

### What Claude Code gets, and what it does not

`CLAUDE.md` and `skills/` travel as-is. `settings.json` is filtered to an **allowlist** — currently just `permissions`:

| Key | Seeded? | Why |
|---|---|---|
| `permissions` | ✅ | Portable; the allowlist is as useful in a sandbox as on the host |
| `hooks` | ❌ | Shells out to `rtk`, which is not in the image — it would fail on *every* tool call |
| `statusLine` | ❌ | Runs `cship`, likewise absent |
| `enabledPlugins`, `extraKnownMarketplaces` | ❌ | Need registry access, which is gone under `--network none` |
| `sandbox` | ❌ | Claude Code's own sandboxing, redundant inside a container |

An allowlist rather than a denylist, deliberately: a new host-specific key added to `settings.json` later is ignored by default, instead of silently breaking every sandbox. If node is somehow unavailable in the image, the file is dropped rather than seeded unfiltered — no settings is a working Claude Code, wrong settings is a broken one.

`CLAUDE.md` is copied with `@import` lines dropped when their target was not seeded. `@RTK.md` is the live case: RTK is a host-side hook plus binary, so its instructions are actively wrong inside a sandbox, and a dangling import is worse than a missing line.

MCP servers are still **not** seeded: they live in `~/.claude.json`, runtime state this repo deliberately does not sync. To give Claude Code the same Playwright MCP server inside a sandbox, run this once per sandbox (the isolated `~/.claude` volume persists it):

```bash
claude mcp add playwright -- playwright-mcp
```

A project-level `.mcp.json` works too, but it is committed and shared with everyone on the repo, who will not have that binary unless they also use this sandbox:

```json
{
  "mcpServers": {
    "playwright": {
      "command": "playwright-mcp",
      "args": []
    }
  }
}
```

Either way the binary resolves from `PATH` with no download, so it works under `--network none`.

If you really want to reuse host agent auth, opt in explicitly:

```bash
sandbox start --host-auth
sandbox shell --host-auth
# or make it the default for start/shell:
SANDBOX_MOUNT_HOST_AUTH=1 sandbox
```

`--host-auth` mounts these paths read-write when present:

```text
~/.claude      → /home/developer/.claude
~/.claude.json → /home/developer/.claude.json
~/.gemini      → /home/developer/.gemini
~/.pi          → /home/developer/.pi
```

Treat `--host-auth` as unsafe for untrusted repositories: anything running in the sandbox can read, modify, or exfiltrate those credentials.

On SELinux Linux hosts, set extra bind options if needed:

```bash
SANDBOX_BIND_EXTRA_OPTIONS=z sandbox start
```

The default intentionally avoids automatic `:Z` relabeling of host paths.

### git push and `gh`

`~/.gitconfig` is mounted read-only and delegates GitHub credentials to `gh auth git-credential`. The `gh` CLI is installed in the image, but its auth state (`~/.config/gh/hosts.yml`) is **not** mounted — that is the point of the isolation default. So the first push from a fresh sandbox fails until you authenticate inside it:

```bash
gh auth login
```

Use `--host-auth` only if you would rather share host credentials wholesale, and only for repositories you trust.

`git-lfs` is also installed in the image: the same mounted `.gitconfig` marks the LFS filter as `required = true`, so git operations in LFS repos would hard-fail without the binary. No `git lfs install` is needed inside the sandbox — the filter config it would write comes in via the mount.

SSH remotes do not work from a sandbox: `~/.ssh` is never mounted (that is the isolation default working as intended), so `git@github.com:` URLs fail with a key error or an authentication prompt. Use HTTPS remotes — the mounted `.gitconfig` routes their credentials through `gh` once you have authenticated inside the sandbox.

### Network egress

By default the sandbox has unrestricted network egress, which is what agent CLIs and package managers need. For untrusted code, cut it off:

```bash
sandbox recreate --no-network        # equivalent to --network none
SANDBOX_NETWORK=none sandbox         # make it the default
```

With `--network none` the sandbox cannot reach the internet at all: `mise install`, `npm install`, and the agent CLIs will fail, and published ports are unreachable. It is meant for inspecting or running untrusted code after the toolchain is already installed. Allowlist-based egress filtering (proxy or firewall) is out of scope here — see [`ALTERNATIVES.md`](./ALTERNATIVES.md).

`--network host` is accepted but warns: it shares the host network namespace, so the sandbox can reach services bound to `localhost` on your machine.

## Project environment

Project-specific environment variables can be placed in `.env.sandbox`. Because that file can be committed by the repository, it is never loaded silently — the variable names are printed at startup (values are not, since they may be secrets). Skip it entirely with:

```bash
SANDBOX_ENV_FILE=0 sandbox
```

## First use

```bash
./install.sh --with-deps

sandbox build
cd /path/to/project
sandbox
```

`install.sh` links `sandbox` into `~/.local/bin` (already on `PATH`), so it works from interactive shells, scripts, and non-zsh shells alike.

On macOS, `install.sh --with-deps` installs Podman and initializes/starts the Podman machine when possible, sizing it to 8 GB RAM / 4 CPUs (clamped to half the host). The default 2 GB machine cannot honor the sandbox's default `--memory 8g` ceiling, and compiling Erlang from source — the first thing a new Elixir sandbox does — can OOM inside it. The first `podman machine init` downloads a VM image (~1 GB). If Podman is installed separately and unavailable, run:

```bash
podman machine init --memory 8192 --cpus 4
podman machine start
```

## Limited devcontainer.json support

If a project contains `.devcontainer/devcontainer.json`, the sandbox does limited parsing before `podman run`:

- `forwardPorts`: numeric ports are published on localhost only (`-p 127.0.0.1:PORT:PORT`), and recorded on the `sandbox.ports` label alongside anything given with `--port`. They are one list: a port named by both is published once (Podman fails outright on a duplicate), and `sandbox list` and drift detection see everything the container actually exposes rather than only the command-line half.
- `mounts`: string mounts are **never applied silently** — they come from the repository itself, so a malicious repo could point them at any host path. When `jq` is available the CLI lists them and asks for confirmation; in non-interactive sessions they are skipped. Set `SANDBOX_APPLY_DEVCONTAINER_MOUNTS=1` to apply them without asking (only for repos you trust).

The file is treated as JSONC, because that is what VS Code's own templates emit: comments and trailing commas are stripped by a string-aware normalizer (so a `//` inside a `$schema` URL survives), and the result is used only after `jq` confirms it parses. A file that still fails to parse is reported at startup rather than silently yielding nothing — ports then fall back to the approximate `grep` recovery, mounts stay ignored.

`forwardPorts` has that `grep` fallback when `jq` is missing or the file is unparseable; `mounts` does not, and are ignored instead. A port recovered approximately is at worst an extra localhost binding — a mount recovered approximately is an arbitrary host-path grant.

Drift warnings still fire only for options *you* asked for, so editing `forwardPorts` after the container exists does not warn on its own. `sandbox list` reflects the container's real ports either way; `sandbox recreate` picks up the new ones.

This is intentionally not a full Dev Containers implementation. For full spec compatibility, use `devcontainers/cli` or DevPod; see [`ALTERNATIVES.md`](./ALTERNATIVES.md).

## Rebuilding the image

Existing containers keep using the image they were created from. After `sandbox build`, run:

```bash
sandbox recreate
```

If you try to start, `exec` into, or restart a stale container, the CLI detects the image mismatch and asks you to recreate it. The one exception is `sandbox shell` into an *already-running* stale sandbox: it warns but still opens the shell, so a rebuild never locks you out of in-flight work. `sandbox list` shows a `STALE` column so drift is visible before it bites.

Podman caches the layer that installs the agent CLIs, so a plain `sandbox build` will not pick up new Claude/Gemini releases. Use `sandbox build --update-agents` for that, or `--fresh` for a full rebuild.

The Pi CLI is deliberately not installed in the image (it has no pinned public package), but an isolated `~/.pi` volume is still provisioned so that installing Pi in-container keeps its state per-project.

## Environment overrides

```text
SANDBOX_IMAGE_NAME                  Image name (default: localhost/agent-sandbox-lab)
SANDBOX_CONTAINER_PREFIX            Container/volume name prefix (default: sbx)
SANDBOX_CONTAINER_USER              In-container user (default: developer)
SANDBOX_MOUNT_HOST_AUTH=1           Make --host-auth the default for start/shell
SANDBOX_NETWORK=none                Default network mode when --network is not given
SANDBOX_ENV_FILE=0                  Do not load <project>/.env.sandbox
SANDBOX_BIND_EXTRA_OPTIONS=z        Extra Podman bind options, e.g. z for SELinux
SANDBOX_APPLY_DEVCONTAINER_MOUNTS=1 Apply devcontainer.json mounts without asking
SANDBOX_MEMORY=8g                   Memory ceiling for new containers (0 = no limit)
SANDBOX_PIDS_LIMIT=4096             Process ceiling for new containers (0 = no limit)
SANDBOX_UID=1000                    Uid of the image user, used for the Linux keep-id mapping
SANDBOX_GID=1000                    Gid of the image user, same mapping
```

`SANDBOX_CONTAINER_USER` only moves the in-container mount targets; the user baked into the image is fixed at build time (`SANDBOX_USER` build arg), so overriding it is only useful together with an image built to match. `SANDBOX_UID`/`SANDBOX_GID` follow the same rule for the numeric ids — set them to whatever the image was built with.

## Checks

```bash
tools/sandbox/test.sh
```

A stub-driven suite validating shell syntax, CLI error handling, and the exact `podman run` arguments the CLI composes — mounts, labels, ports, resource limits, network mode, env-file handling, collision and staleness handling (for containers and volumes both), drift warnings, `exec` dispatch and quoting (including that `exec` never re-seeds a running sandbox), volume-creation failures, volume reuse across recreates (Podman's `volume create` fails on an existing name, and the stub models that), volume project labels and prune's project-is-gone orphan rule, `rm`'s label-guarded per-project removal, JSONC devcontainer normalization (comments, trailing commas, a `//` inside a string) and the parse-failure report, the exact `socat` relay `expose` composes, `stop --all`, seed-failure diagnostics, container cleanup after a failed initialization, every `SANDBOX_*` override, and that `--help` never reaches a container. It stubs Podman, so it needs no running container and finishes in a couple of seconds. ShellCheck runs too when installed.

The seeding tests go one step further: the stub *executes* the streamed-in payloads against a scratch directory with the same `bash`, `tar`, and `node` the container would use, so the MCP rewrite, the `settings.json` allowlist, `@import` pruning, and the never-overwrite promise are checked by their results rather than by asserting a script was sent.

**These checks never build the image or start a container.** They cover `sandbox.sh` thoroughly and the `Dockerfile` not at all, so image-level regressions — a missing apt package, a base-image user collision — surface only on a real `sandbox build`.
