#!/usr/bin/env bash

# Sandbox CLI - Manage Podman-based development sandboxes.

IMAGE_NAME="${SANDBOX_IMAGE_NAME:-localhost/agent-sandbox-lab}"
CONTAINER_PREFIX="${SANDBOX_CONTAINER_PREFIX:-sbx}"
CONTAINER_USER="${SANDBOX_CONTAINER_USER:-developer}"
CONTAINER_HOME="/home/${CONTAINER_USER}"
CONTAINER_MISE_DIR="${CONTAINER_HOME}/.local/share/mise"

# Podman's container name filter is an unanchored regex, so a bare "sbx-" also
# matches a container merely containing it (e.g. "my-sbx-notes"). 'prune' and
# 'clean' delete what this matches, so anchor it to the start of the name.
# Volumes are prefix-matched in shell instead (see sandbox_volumes): the volume
# filter's matching is less clearly specified, and under Docker's substring
# semantics '^sbx-' would match nothing at all.
SANDBOX_NAME_FILTER="^${CONTAINER_PREFIX}-"

# Generous ceilings, not quotas: without them a runaway agent or build (a fork
# bomb, an unbounded test suite) competes with the host for memory and PIDs.
# Set a limit to 0 to drop it, e.g. on hosts without the memory cgroup
# controller. Like all creation-time options, changes need 'sandbox recreate'.
MEMORY_LIMIT="${SANDBOX_MEMORY:-8g}"
PIDS_LIMIT="${SANDBOX_PIDS_LIMIT:-4096}"

# The uid/gid the image user was created with (the Dockerfile's SANDBOX_UID and
# SANDBOX_GID build args). Only the Linux rootless keep-id mapping reads these;
# overriding them is only useful together with an image built to match, same
# caveat as SANDBOX_CONTAINER_USER.
CONTAINER_UID="${SANDBOX_UID:-1000}"
CONTAINER_GID="${SANDBOX_GID:-1000}"

PARSED_PATH="."
PARSED_HOST_AUTH="0"
PARSED_RECREATE="0"
PARSED_NETWORK=""
PARSED_PORTS=()
# Whether each creation-time option was explicitly requested (flag or SANDBOX_*
# env) rather than left at its parser default. Drift warnings only fire for
# explicit requests.
PARSED_HOST_AUTH_EXPLICIT="0"
PARSED_NETWORK_EXPLICIT="0"
PARSED_PORTS_EXPLICIT="0"

function command_name() {
    local name
    name="${0##*/}"
    if [ "$name" = "sandbox.sh" ]; then
        name="sandbox"
    fi
    printf '%s\n' "$name"
}

function usage() {
    local cmd
    cmd="$(command_name)"

    cat <<USAGE
Usage: $cmd [command] [options] [path]

Default (no command): Start and shell into a sandbox for the current directory.
A bare path is also accepted, e.g. '$cmd ~/Work/my-app'.

Commands:
  build [--fresh|--no-cache] [--update-agents] [--dns SERVER]
                 Build/rebuild the sandbox image. Uses Podman cache by default.
  start [options] [path]
                 Start a sandbox for the project at [path] (default: .)
  shell [options] [path]
                 Open a shell in the sandbox for [path]
  exec [-C|--path path] [--create] [--] <command> [args...]
                 Run one command in the sandbox and return its exit status.
                 Starts a stopped sandbox, but refuses to build a missing one
                 unless --create is given.
  recreate [options] [path]
                 Recreate the sandbox container while preserving named volumes
  list           List sandbox containers with project path and staleness
  expose <port> [path]
                 Forward a port from an already-running sandbox (fallback for
                 when you cannot restart; prefer --port at creation time)
  stop [--all|path]
                 Stop the sandbox for [path], or every running sandbox
  rm [--force] [path]
                 Remove the project's sandbox container AND its volumes —
                 build caches and agent state — asking for confirmation first
  prune          Remove stopped sandbox containers, plus volumes whose recorded
                 project directory no longer exists (all other volumes are kept
                 for reuse, so prune is safe to repeat)
  clean [--force]
                 Stop and remove ALL sandboxes and volumes (asks first)
  help           Show this help

Options for start/shell/recreate:
  --port N       Publish container port N on 127.0.0.1:N. Repeatable. Ports can
                 only be published at creation time, so this needs --recreate on
                 an existing sandbox.
  --network MODE Podman network mode: none, bridge, slirp4netns, pasta, host.
                 Use 'none' to cut off network egress for untrusted code.
  --no-network   Shorthand for --network none.
  --host-auth    Mount host agent auth/config directories instead of isolated
                 per-project volumes. Risky; exposes those secrets to the sandbox.
  --recreate     Replace the container if it already exists; preserves volumes.

Environment:
  SANDBOX_MOUNT_HOST_AUTH=1   Make --host-auth the default for start/shell.
  SANDBOX_NETWORK=none        Default network mode when --network is not given.
  SANDBOX_MEMORY=8g           Memory ceiling for new containers (0 = no limit).
  SANDBOX_PIDS_LIMIT=4096     Process ceiling for new containers (0 = no limit).
  SANDBOX_UID=1000            Uid/gid of the image user, used for the Linux
  SANDBOX_GID=1000            keep-id mapping; match the image's build args.
  SANDBOX_ENV_FILE=0          Do not load <project>/.env.sandbox.
  SANDBOX_BIND_EXTRA_OPTIONS=z Add extra Podman bind options, e.g. z for SELinux.
  SANDBOX_APPLY_DEVCONTAINER_MOUNTS=1
                              Apply devcontainer.json mounts without asking.
  SANDBOX_IMAGE_NAME          Override the image name (default: $IMAGE_NAME).
  SANDBOX_CONTAINER_PREFIX    Override the container name prefix (default: $CONTAINER_PREFIX).
  SANDBOX_CONTAINER_USER      Override the in-container user (default: $CONTAINER_USER).
USAGE
}

function script_dir() {
    local source dir
    source="${BASH_SOURCE[0]}"

    while [ -h "$source" ]; do
        dir="$(cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd)" || return 1
        source="$(readlink "$source")" || return 1
        if [[ "$source" != /* ]]; then
            source="$dir/$source"
        fi
    done

    cd -P "$(dirname "$source")" >/dev/null 2>&1 && pwd
}

function resolve_project_path() {
    local input
    input="${1:-.}"

    if [ ! -d "$input" ]; then
        echo "Error: Project path must be an existing directory: $input" >&2
        return 1
    fi

    local resolved
    if ! resolved="$(cd "$input" >/dev/null 2>&1 && pwd -P)"; then
        echo "Error: Cannot resolve project path (missing permissions?): $input" >&2
        return 1
    fi
    printf '%s\n' "$resolved"
}

function hash_string() {
    if command -v md5sum >/dev/null 2>&1; then
        printf '%s' "$1" | md5sum | cut -c1-8
    elif command -v md5 >/dev/null 2>&1; then
        printf '%s' "$1" | md5 -q | cut -c1-8
    else
        printf '%s' "$1" | openssl md5 | awk '{print $NF}' | cut -c1-8
    fi
}

# Expects a path already canonicalized by resolve_project_path — every entry
# point resolves before calling, and hashing the canonical form is what keeps
# two spellings of one directory on the same sandbox.
function get_container_name() {
    local hash
    hash="$(hash_string "$1")" || return 1
    printf '%s-%s\n' "$CONTAINER_PREFIX" "$hash"
}

function require_command() {
    local required hint
    required="$1"
    hint="${2:-}"

    if ! command -v "$required" >/dev/null 2>&1; then
        echo "Error: '$required' is not installed." >&2
        if [ -n "$hint" ]; then
            echo "$hint" >&2
        fi
        return 1
    fi
}

function require_podman() {
    require_command podman "Run './install.sh --with-deps' from the dotfiles repo." || return 1

    if ! podman info >/dev/null 2>&1; then
        echo "Error: Podman is installed but not available." >&2
        echo "On macOS, run: podman machine init && podman machine start" >&2
        return 1
    fi
}

function container_running() {
    local name
    name="$1"
    podman ps --format "{{.Names}}" | grep -Fxq "$name"
}

function container_exists() {
    local name
    name="$1"
    podman ps -a --format "{{.Names}}" | grep -Fxq "$name"
}

function image_exists() {
    podman image exists "$IMAGE_NAME"
}

function current_image_id() {
    podman image inspect "$IMAGE_NAME" --format "{{.Id}}" 2>/dev/null
}

function container_image_id() {
    local name
    name="$1"
    podman inspect "$name" --format "{{.Image}}" 2>/dev/null
}

function container_is_stale() {
    local name current existing
    name="$1"

    image_exists || return 1
    current="$(current_image_id)" || return 1
    existing="$(container_image_id "$name")" || return 1

    [ -n "$current" ] && [ -n "$existing" ] && [ "$current" != "$existing" ]
}

function fail_if_stale() {
    local name path cmd
    name="$1"
    path="$2"
    cmd="$(command_name)"

    if container_is_stale "$name"; then
        cat >&2 <<STALE
Error: Sandbox '$name' was created from an older image.
Run one of:
  $cmd recreate "$path"
  $cmd start --recreate "$path"
STALE
        return 1
    fi
}

# A running stale sandbox still accepts a shell: refusing would lock the user
# away from in-flight work right after 'sandbox build'. Everything else — start,
# exec, and shells that need the container (re)started — still refuses via
# fail_if_stale, since those have no live session to protect.
function warn_if_stale() {
    local name path
    name="$1"
    path="$2"

    if container_is_stale "$name"; then
        cat >&2 <<STALE
Warning: Sandbox '$name' was created from an older image.
Finish up, then run '$(command_name) recreate "$path"' to pick up the new one.
STALE
    fi
}

function remove_existing_container() {
    local name
    name="$1"

    if container_running "$name"; then
        echo "Stopping sandbox '$name'..."
        podman stop "$name" >/dev/null
    fi

    if container_exists "$name"; then
        echo "Removing sandbox container '$name'..."
        podman rm "$name" >/dev/null
    fi
}

# The project a volume was created for, recorded as a label by create_volume.
# Empty for volumes created before labeling existed.
function volume_label() {
    podman volume inspect "$1" --format '{{index .Labels "sandbox.project"}}' 2>/dev/null
}

# A volume that fails to create otherwise surfaces much later, as a 'podman run'
# error naming a volume the user never typed. Check it here, where the name and
# the reason are both still in hand.
#
# Existing volumes are reused, not re-created: unlike Docker's, Podman's
# 'volume create' fails on a name that already exists, and sandbox volumes
# deliberately outlive their container — 'recreate', 'prune', and a failed
# initialization all keep them for the next start. 'volume exists' is used
# rather than create's --ignore flag, which distro Podmans older than 4.4
# do not have.
function create_volume() {
    local volume project labeled
    volume="$1"
    project="$2"

    if podman volume exists "$volume" 2>/dev/null; then
        # Volume names carry the same truncated path hash as container names,
        # so the collision verify_project_identity refuses for containers can
        # happen here too — and reusing another project's volume silently
        # shares its build caches and agent state. An unlabeled volume (from
        # before labeling existed) is reused as before.
        labeled="$(volume_label "$volume")"
        if [ -n "$labeled" ] && [ "$labeled" != "$project" ]; then
            cat >&2 <<COLLISION
Error: Volume '$volume' already belongs to a different project.
  existing:  $labeled
  requested: $project
The short project-path hash collided. Remove that volume, or set
SANDBOX_CONTAINER_PREFIX to a different value for this project.
COLLISION
            return 1
        fi
        return 0
    fi

    # The label is how 'prune' tells a volume whose project still exists (kept
    # for the next start) from a true orphan whose project directory is gone.
    if ! podman volume create --label "sandbox.project=${project}" "$volume" >/dev/null; then
        echo "Error: Could not create sandbox volume '$volume'." >&2
        return 1
    fi
}

# Initialization failed after 'podman run' already produced a container. Leaving
# it behind is worse than having none: its volumes are still root-owned and no
# toolchain is installed, but every later command sees a running container and
# hands back a shell into it, reporting success. Remove it so the next start
# retries from scratch. Named volumes are untouched, exactly as in 'recreate',
# so any build cache from an earlier attempt survives.
function abort_partial_start() {
    local name reason
    name="$1"
    reason="$2"

    echo "Error: $reason" >&2
    echo "Removing the partially created sandbox so the next start retries cleanly." >&2
    remove_existing_container "$name" >&2
    return 1
}

function truthy() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

function default_host_auth() {
    if truthy "${SANDBOX_MOUNT_HOST_AUTH:-0}"; then
        printf '1\n'
    else
        printf '0\n'
    fi
}

function validate_network() {
    case "${1:-}" in
        none|bridge|slirp4netns|pasta)
            ;;
        host)
            echo "Warning: --network host shares the host network namespace." >&2
            echo "The sandbox can then reach services bound to localhost on your machine." >&2
            ;;
        *)
            echo "Error: Unsupported network mode: ${1:-}" >&2
            echo "Supported: none, bridge, slirp4netns, pasta, host." >&2
            return 1
            ;;
    esac
}

# For subcommands that take no arguments at all. Returns 2 when help was shown,
# matching parse_project_args. Without this, 'prune --help' reached prune() with
# the flag silently discarded and removed containers instead of printing usage.
function parse_no_args() {
    local subcommand
    subcommand="$1"
    shift

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                return 2
                ;;
            *)
                echo "Error: '$subcommand' takes no arguments (got: $1)" >&2
                echo "Usage: $(command_name) $subcommand" >&2
                return 1
                ;;
        esac
    done
}

# For subcommands that take an optional path but none of the creation-time
# options. 'stop --port 4000' used to parse happily and then ignore the port.
function parse_path_only() {
    local subcommand saw_path
    subcommand="$1"
    shift
    saw_path=0
    PARSED_PATH="."

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                return 2
                ;;
            --)
                shift
                if [ "$#" -gt 0 ]; then
                    if [ "$saw_path" -eq 1 ]; then
                        echo "Error: Too many project paths provided." >&2
                        return 1
                    fi
                    PARSED_PATH="$1"
                    saw_path=1
                    shift
                fi
                if [ "$#" -gt 0 ]; then
                    echo "Error: Too many project paths provided." >&2
                    return 1
                fi
                break
                ;;
            --*)
                echo "Error: '$subcommand' does not accept option: $1" >&2
                echo "Usage: $(command_name) $subcommand [path]" >&2
                return 1
                ;;
            *)
                if [ "$saw_path" -eq 1 ]; then
                    echo "Error: Too many project paths provided." >&2
                    return 1
                fi
                PARSED_PATH="$1"
                saw_path=1
                ;;
        esac
        shift
    done
}

function parse_project_args() {
    local saw_path
    saw_path=0
    PARSED_PATH="."
    PARSED_HOST_AUTH="$(default_host_auth)"
    PARSED_RECREATE="0"
    PARSED_NETWORK="${SANDBOX_NETWORK:-}"
    PARSED_PORTS=()
    PARSED_HOST_AUTH_EXPLICIT="0"
    PARSED_NETWORK_EXPLICIT="0"
    PARSED_PORTS_EXPLICIT="0"

    if truthy "${SANDBOX_MOUNT_HOST_AUTH:-0}"; then
        PARSED_HOST_AUTH_EXPLICIT="1"
    fi

    if [ -n "$PARSED_NETWORK" ]; then
        PARSED_NETWORK_EXPLICIT="1"
        validate_network "$PARSED_NETWORK" || return 1
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --host-auth)
                PARSED_HOST_AUTH="1"
                PARSED_HOST_AUTH_EXPLICIT="1"
                ;;
            --no-host-auth)
                PARSED_HOST_AUTH="0"
                PARSED_HOST_AUTH_EXPLICIT="1"
                ;;
            --recreate)
                PARSED_RECREATE="1"
                ;;
            --port|--port=*)
                if [ "$1" = "--port" ]; then
                    shift
                    if [ "$#" -eq 0 ] || [[ "$1" == -* ]]; then
                        echo "Error: --port requires a port number." >&2
                        return 1
                    fi
                    validate_port "$1" || return 1
                    PARSED_PORTS+=("$1")
                else
                    validate_port "${1#--port=}" || return 1
                    PARSED_PORTS+=("${1#--port=}")
                fi
                PARSED_PORTS_EXPLICIT="1"
                ;;
            --network|--network=*)
                if [ "$1" = "--network" ]; then
                    shift
                    if [ "$#" -eq 0 ] || [[ "$1" == -* ]]; then
                        echo "Error: --network requires a mode." >&2
                        return 1
                    fi
                    validate_network "$1" || return 1
                    PARSED_NETWORK="$1"
                else
                    validate_network "${1#--network=}" || return 1
                    PARSED_NETWORK="${1#--network=}"
                fi
                PARSED_NETWORK_EXPLICIT="1"
                ;;
            --no-network)
                PARSED_NETWORK="none"
                PARSED_NETWORK_EXPLICIT="1"
                ;;
            -h|--help)
                usage
                return 2
                ;;
            --)
                shift
                if [ "$#" -gt 0 ]; then
                    if [ "$saw_path" -eq 1 ]; then
                        echo "Error: Too many project paths provided." >&2
                        return 1
                    fi
                    PARSED_PATH="$1"
                    saw_path=1
                    shift
                fi
                if [ "$#" -gt 0 ]; then
                    echo "Error: Too many project paths provided." >&2
                    return 1
                fi
                break
                ;;
            --*)
                echo "Error: Unknown option: $1" >&2
                return 1
                ;;
            *)
                if [ "$saw_path" -eq 1 ]; then
                    echo "Error: Too many project paths provided." >&2
                    return 1
                fi
                PARSED_PATH="$1"
                saw_path=1
                ;;
        esac
        shift
    done
}

function bind_mount_spec() {
    local source target mode extra
    source="$1"
    target="$2"
    mode="$3"
    extra="${SANDBOX_BIND_EXTRA_OPTIONS:-}"

    if [ -n "$extra" ]; then
        printf '%s:%s:%s,%s\n' "$source" "$target" "$mode" "$extra"
    else
        printf '%s:%s:%s\n' "$source" "$target" "$mode"
    fi
}

function warn_host_auth() {
    cat >&2 <<WARNING
Warning: --host-auth mounts host agent credentials/config into the sandbox.
A malicious project or agent command can read, modify, or exfiltrate those files.
Prefer the default per-project named volumes for untrusted repositories.
WARNING
}

function container_label() {
    local name label
    name="$1"
    label="$2"

    podman inspect "$name" --format "{{index .Config.Labels \"${label}\"}}" 2>/dev/null
}

# The container name is a truncated hash of the project path, so two different
# projects can in principle map to the same name. The full path is recorded as a
# label at creation; refuse to reuse a container that belongs to another project
# rather than silently sharing its /workspace mount and build volumes.
function verify_project_identity() {
    local name path labeled
    name="$1"
    path="$2"

    labeled="$(container_label "$name" sandbox.project)"
    if [ -n "$labeled" ] && [ "$labeled" != "$path" ]; then
        cat >&2 <<COLLISION
Error: Sandbox '$name' already belongs to a different project.
  existing:  $labeled
  requested: $path
The short project-path hash collided. Remove the other sandbox, or set
SANDBOX_CONTAINER_PREFIX to a different value for this project.
COLLISION
        return 1
    fi
}

# Mount, network, and port options are fixed when the container is created.
# Warn only when the caller explicitly asked for something else (flag or
# SANDBOX_* env). Comparing against parser defaults instead would nag on every
# plain invocation after e.g. 'recreate --port 4000' — and following the
# warning's advice would drop the port that was deliberately configured.
function warn_option_drift() {
    local name host_auth network ports existing drift
    name="$1"
    host_auth="$2"
    network="$3"
    ports="$4"
    drift=""

    if [ "$PARSED_HOST_AUTH_EXPLICIT" = "1" ]; then
        existing="$(container_label "$name" sandbox.host-auth)"
        if [ -n "$existing" ] && [ "$existing" != "$host_auth" ]; then
            drift+="  host-auth: $existing -> $host_auth"$'\n'
        fi
    fi

    if [ "$PARSED_NETWORK_EXPLICIT" = "1" ]; then
        existing="$(container_label "$name" sandbox.network)"
        if [ "$existing" != "$network" ]; then
            drift+="  network: ${existing:-<default>} -> ${network:-<default>}"$'\n'
        fi
    fi

    if [ "$PARSED_PORTS_EXPLICIT" = "1" ]; then
        existing="$(container_label "$name" sandbox.ports)"
        if [ "$existing" != "$ports" ]; then
            drift+="  ports: ${existing:-<none>} -> ${ports:-<none>}"$'\n'
        fi
    fi

    if [ -n "$drift" ]; then
        cat >&2 <<DRIFT
Warning: Sandbox '$name' was created with different options:
${drift%$'\n'}
These only apply at creation. Run '$(command_name) recreate' to change them.
DRIFT
    fi
}

# MCP servers are rewritten on the way in to launch the copies already installed
# in the image rather than going through npx.
#
# 'npx -y @playwright/mcp' does not resolve the preinstalled package: npm exec
# searches the global bin directory for a file named exactly "@playwright/mcp"
# and never finds one, because the package's bin is "playwright-mcp". So it falls
# through to a registry manifest fetch on every launch — which fails outright
# under --network none, and otherwise pulls whatever version is newest, drifting
# from the Playwright browsers pinned into the image. The host copy of this
# config keeps using npx, since nothing is preinstalled there.
SEED_MCP_BINS='{"@playwright/mcp": "playwright-mcp"}'

# Files carried from the repo's .claude/ into a sandbox's isolated ~/.claude.
# CLAUDE.md and skills/ are plain instructions and travel as they are;
# settings.json is filtered (see below). Everything else in .claude/ is
# host-bound: hooks/ shells out to binaries that exist only on the host, and
# keybindings are a terminal-UI concern with no meaning in a container.
SEED_CLAUDE_FILES=(CLAUDE.md skills settings.json)

# settings.json keeps only these keys on the way in.
#
# An allowlist, not a denylist. Every other key in the host file is host-bound:
# 'hooks' and 'statusLine' invoke binaries this image does not carry (rtk,
# cship), so a seeded copy would fail on every single tool call, and
# 'enabledPlugins'/'extraKnownMarketplaces' need registry access that is gone
# under --network none. With a denylist, the next host-specific key added to
# settings.json would silently break every sandbox instead of being ignored.
SEED_CLAUDE_SETTINGS_KEYS='["permissions"]'

# Emitted as a quoted heredoc and passed to 'bash -c' with the container home and
# the bin map as positional arguments, so nothing is interpolated host-side.
function gemini_seed_script() {
    cat <<'REMOTE'
set -e
home="$1"
bins="$2"
target="$home/.gemini/settings.json"

mkdir -p "$home/.gemini"

# stdin is drained even when the file already exists, so the host-side write
# never dies on a broken pipe.
if [ -e "$target" ]; then
    cat >/dev/null
    exit 0
fi

# node ships with the image; copying verbatim is a fallback for a stripped one.
if ! command -v node >/dev/null 2>&1; then
    cat > "$target"
    exit 0
fi

node -e '
const fs = require("fs");
const bins = JSON.parse(process.argv[2]);
let raw = "";
process.stdin.on("data", (chunk) => (raw += chunk));
process.stdin.on("end", () => {
  let config;
  try {
    config = JSON.parse(raw);
  } catch {
    fs.writeFileSync(process.argv[1], raw);
    return;
  }
  for (const server of Object.values(config.mcpServers || {})) {
    if (server.command !== "npx" || !Array.isArray(server.args)) continue;
    const index = server.args.findIndex((arg) => bins[arg]);
    if (index === -1) continue;
    server.command = bins[server.args[index]];
    server.args = server.args.slice(index + 1);
  }
  fs.writeFileSync(process.argv[1], JSON.stringify(config, null, 2) + "\n");
});
' "$target" "$bins"
REMOTE
}

# Streamed in as a tar on stdin. Same reasoning as the Gemini payload: emitted
# as a quoted heredoc, with the container home and the settings allowlist passed
# as positional arguments, so nothing is interpolated host-side.
function claude_seed_script() {
    cat <<'REMOTE'
set -e
home="$1"
keys="$2"
dir="$home/.claude"

mkdir -p "$dir"

# Recorded before extracting: only a file this run creates may be rewritten
# below. One that was already in the volume belongs to the sandbox.
had_settings=0
if [ -e "$dir/settings.json" ]; then
    had_settings=1
fi

had_instructions=0
if [ -e "$dir/CLAUDE.md" ]; then
    had_instructions=1
fi

# Staged inside the target rather than under /tmp: the directory was just
# created so it is known writable, the copy below stays on one filesystem, and
# nothing depends on how a given mktemp resolves TMPDIR.
staging="$dir/.seed-staging.$$"
# A run killed outright never fires its trap, so clear anything an earlier one
# left behind rather than let these accumulate in the volume across restarts.
rm -rf "$dir"/.seed-staging.*
trap 'rm -rf "$staging"' EXIT
mkdir -p "$staging"
tar -xf - -C "$staging"

# Copy only paths that are not already present. Extracting straight over the
# volume would clobber edits made inside the sandbox; skipping the seed whenever
# the directory is non-empty would mean a skill added upstream never arrives.
# Symlinks travel too (-type l, cp -RP): tar carries them into staging, and a
# plain '-type f' walk would drop a skill's symlinked file silently. The -L
# test keeps the never-overwrite promise even when the destination is a
# dangling link.
cd "$staging"
find . \( -type f -o -type l \) -print | while IFS= read -r rel; do
    if [ ! -e "$dir/$rel" ] && [ ! -L "$dir/$rel" ]; then
        mkdir -p "$dir/$(dirname "$rel")"
        cp -RP "$staging/$rel" "$dir/$rel"
    fi
done
cd /

if [ "$had_settings" -eq 0 ] && [ -e "$dir/settings.json" ]; then
    if command -v node >/dev/null 2>&1; then
        node -e '
const fs = require("fs");
const [file, allowed] = process.argv.slice(1);
const keys = new Set(JSON.parse(allowed));
let config;
try {
  config = JSON.parse(fs.readFileSync(file, "utf8"));
} catch {
  fs.rmSync(file);
  process.exit(0);
}
const filtered = {};
for (const key of Object.keys(config)) {
  if (keys.has(key)) filtered[key] = config[key];
}
fs.writeFileSync(file, JSON.stringify(filtered, null, 2) + "\n");
' "$dir/settings.json" "$keys"
    else
        # Unfilterable without node, and shipping it whole would point hooks and
        # the status line at host binaries that do not exist here. Drop it: no
        # settings is a working Claude Code, bad settings is a broken one.
        rm -f "$dir/settings.json"
    fi
fi

# CLAUDE.md @imports sibling files that are deliberately not seeded — RTK.md
# documents a host-side hook plus binary, so its instructions are actively wrong
# in here. Drop those lines rather than leave imports resolving to nothing.
if [ "$had_instructions" -eq 0 ] && [ -e "$dir/CLAUDE.md" ]; then
    kept=""
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            @*)
                if [ ! -e "$dir/${line#@}" ]; then
                    continue
                fi
                ;;
        esac
        kept+="$line"$'\n'
    done < "$dir/CLAUDE.md"
    printf '%s' "$kept" > "$dir/CLAUDE.md"
fi
REMOTE
}

# With isolated agent-state volumes the host's ~/.gemini and ~/.claude never
# reach the sandbox, so shared config would be lost unless --host-auth is used.
# Stream the files we care about in over stdin instead.
#
# This used to read them from a read-only bind mount of the whole dotfiles repo.
# That contradicted the tool's main promise: the repo carries .claude/ settings,
# hooks, and skills, so every sandbox could read all of it (and learned the host
# path it lives at) purely to copy a few hundred bytes. Piping through podman
# exec needs no host mount at all, which keeps the rule simple: the only host
# paths in a sandbox are the project, .gitconfig, and .gitignore_global.
#
# Existing files are never overwritten, so in-sandbox edits survive restarts.
function seed_agent_config() {
    local name dotfiles_dir host_auth
    name="$1"
    dotfiles_dir="$2"
    host_auth="$3"

    if [ "$host_auth" = "1" ]; then
        return 0
    fi

    if ! has_seed_sources "$dotfiles_dir"; then
        return 0
    fi

    echo "Seeding agent config into isolated volumes..."
    seed_gemini_config "$name" "$dotfiles_dir"
    seed_claude_config "$name" "$dotfiles_dir"
}

function has_seed_sources() {
    local dotfiles_dir entry
    dotfiles_dir="$1"

    if [ -f "${dotfiles_dir}/.gemini/settings.json" ]; then
        return 0
    fi

    for entry in "${SEED_CLAUDE_FILES[@]}"; do
        if [ -e "${dotfiles_dir}/.claude/${entry}" ]; then
            return 0
        fi
    done

    return 1
}

function seed_gemini_config() {
    local name dotfiles_dir source_file
    name="$1"
    dotfiles_dir="$2"

    source_file="${dotfiles_dir}/.gemini/settings.json"
    if [ ! -f "$source_file" ]; then
        return 0
    fi

    echo "  Gemini: settings.json"
    # Output is captured, not discarded: the payloads are silent on success,
    # and on failure the underlying error is the only way to debug them.
    local output
    if ! output="$(podman exec -i "$name" bash -c "$(gemini_seed_script)" _ \
        "$CONTAINER_HOME" "$SEED_MCP_BINS" < "$source_file" 2>&1)"; then
        echo "Warning: Could not seed Gemini config into the sandbox." >&2
        if [ -n "$output" ]; then
            printf '%s\n' "$output" >&2
        fi
    fi
}

# Claude Code's MCP servers are deliberately not seeded: they live in
# ~/.claude.json, which is runtime state this repo does not sync. Run
# 'claude mcp add playwright -- playwright-mcp' inside the sandbox, or commit a
# project-level .mcp.json.
function seed_claude_config() {
    local name dotfiles_dir source_dir entry
    name="$1"
    dotfiles_dir="$2"
    source_dir="${dotfiles_dir}/.claude"

    local present=()
    for entry in "${SEED_CLAUDE_FILES[@]}"; do
        if [ -e "${source_dir}/${entry}" ]; then
            present+=("$entry")
        fi
    done

    if [ "${#present[@]}" -eq 0 ]; then
        return 0
    fi

    echo "  Claude Code: ${present[*]}"
    # COPYFILE_DISABLE stops macOS bsdtar from packing xattrs as AppleDouble
    # "._name" members, which GNU tar in the container extracts as real files —
    # scattering ._CLAUDE.md and ._SKILL.md through the seeded tree. Ignored by
    # GNU tar on Linux hosts. Output is captured, not discarded: the payload is
    # silent on success, and on failure the underlying error is the only way
    # to debug it. pipefail makes a tar-side failure (an unreadable source
    # file) fail the seed with tar's own message, instead of silently seeding
    # a truncated tree; tar's stderr goes to the capture, never into the pipe.
    local output
    if ! output="$( (set -o pipefail
        COPYFILE_DISABLE=1 tar -cf - -C "$source_dir" "${present[@]}" |
            podman exec -i "$name" bash -c "$(claude_seed_script)" _ \
                "$CONTAINER_HOME" "$SEED_CLAUDE_SETTINGS_KEYS") 2>&1)"; then
        echo "Warning: Could not seed Claude Code config into the sandbox." >&2
        if [ -n "$output" ]; then
            printf '%s\n' "$output" >&2
        fi
    fi
}

# Seeding also runs when an existing container is started, found running, or
# opened with 'shell', not only at creation: it copies only what is absent, so
# config added upstream lands on the next 'start' or 'shell' without needing a
# recreate. host-auth is
# read from the container's label rather than the current invocation's flags —
# a sandbox created with --host-auth has the real host directories mounted,
# and seeding into those would write to the host. A missing label is treated
# the same way, conservatively.
function seed_existing_container() {
    local name host_auth sandbox_dir dotfiles_dir
    name="$1"

    host_auth="$(container_label "$name" sandbox.host-auth)"
    if [ "$host_auth" != "0" ]; then
        return 0
    fi

    sandbox_dir="$(script_dir)" || return 1
    dotfiles_dir="$(cd "$sandbox_dir/../.." && pwd -P)" || return 1
    seed_agent_config "$name" "$dotfiles_dir" "0"
}

function build() {
    local build_args=()

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --fresh|--no-cache)
                build_args+=(--no-cache)
                ;;
            --update-agents)
                # Podman caches the npm layer, so an unpinned 'npm install -g'
                # does not pick up new releases on a normal build. Bust just
                # that layer instead of forcing a full --no-cache rebuild.
                build_args+=(--build-arg "AGENT_CLI_EPOCH=$(date +%s)")
                ;;
            --dns)
                shift
                if [ "$#" -eq 0 ] || [[ "$1" == -* ]]; then
                    echo "Error: --dns requires a server value." >&2
                    return 1
                fi
                build_args+=(--dns "$1")
                ;;
            -h|--help)
                usage
                return 0
                ;;
            *)
                echo "Error: Unknown build option: $1" >&2
                echo "Usage: $(command_name) build [--fresh|--no-cache] [--update-agents] [--dns SERVER]" >&2
                return 1
                ;;
        esac
        shift
    done

    require_podman || return 1

    local sandbox_dir
    sandbox_dir="$(script_dir)" || return 1

    echo "Building sandbox image..."
    podman build "${build_args[@]}" -t "$IMAGE_NAME" "$sandbox_dir"
}

function devcontainer_path() {
    printf '%s/.devcontainer/devcontainer.json\n' "$1"
}

# devcontainer.json is JSONC in practice: VS Code's own templates ship comments
# and trailing commas, which strict jq rejects. Strip them character by
# character rather than with regexes, so a "//" inside a string (a $schema URL)
# survives. The output is never trusted on its own — devcontainer_as_json only
# uses it after jq confirms the result parses.
function strip_jsonc() {
    awk '
    { src = src $0 "\n" }
    END {
        n = length(src); i = 1; out = ""; in_str = 0; esc = 0
        while (i <= n) {
            c = substr(src, i, 1)
            if (in_str) {
                out = out c
                if (esc) esc = 0
                else if (c == "\\") esc = 1
                else if (c == "\"") in_str = 0
                i++; continue
            }
            if (c == "\"") { in_str = 1; out = out c; i++; continue }
            if (substr(src, i, 2) == "//") {
                while (i <= n && substr(src, i, 1) != "\n") i++
                continue
            }
            if (substr(src, i, 2) == "/*") {
                i += 2
                while (i <= n && substr(src, i, 2) != "*/") i++
                i += 2
                continue
            }
            if (c == "}" || c == "]") {
                while (length(out) > 0 && index(" \t\n\r", substr(out, length(out), 1)) > 0)
                    out = substr(out, 1, length(out) - 1)
                if (substr(out, length(out), 1) == ",")
                    out = substr(out, 1, length(out) - 1)
            }
            out = out c
            i++
        }
        printf "%s", out
    }'
}

# Emits the file's content as strict JSON, normalizing JSONC when needed.
# Fails when even the normalized text does not parse, so callers can tell
# "no ports/mounts requested" from "could not read the file at all" — the
# original code hid that distinction behind 2>/dev/null, and a commented
# devcontainer.json silently lost its ports exactly when jq WAS installed.
function devcontainer_as_json() {
    local file normalized
    file="$1"

    if jq empty "$file" >/dev/null 2>&1; then
        cat "$file"
        return 0
    fi

    normalized="$(strip_jsonc < "$file")"
    if printf '%s' "$normalized" | jq empty >/dev/null 2>&1; then
        printf '%s\n' "$normalized"
        return 0
    fi

    return 1
}

# Prints one numeric forwardPorts entry per line.
#
# The grep fallback covers a missing jq AND a file jq cannot parse even after
# JSONC normalization, because a port is safe to recover approximately: the
# worst case is publishing a number the repo did not ask for, on localhost.
# Mounts get no such fallback (see below) — they are host-path grants, where an
# approximate parse is not acceptable.
function devcontainer_forward_ports() {
    local file port json
    file="$1"

    if command -v jq >/dev/null 2>&1 && json="$(devcontainer_as_json "$file")"; then
        while IFS= read -r port; do
            if [[ "$port" =~ ^[0-9]+$ ]]; then
                printf '%s\n' "$port"
            fi
        done < <(jq -r '.forwardPorts[]?' <<< "$json" 2>/dev/null)
        return 0
    fi

    grep -oE '"forwardPorts"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$file" 2>/dev/null |
        grep -oE '[0-9]+' || true
}

# jq-only, deliberately: a mount grants access to an arbitrary host path, so
# guessing at one with a regex is not acceptable. Without jq — or when the file
# does not parse even after JSONC normalization — mounts are ignored, and
# start_container reports why.
function devcontainer_mount_specs() {
    local file json
    file="$1"

    command -v jq >/dev/null 2>&1 || return 0
    json="$(devcontainer_as_json "$file")" || return 0
    jq -r '.mounts[]? | select(type == "string")' <<< "$json" 2>/dev/null || true
}

# Every port the container will publish: --port requests plus devcontainer
# forwardPorts. Both feed the sandbox.ports label, so 'sandbox list' and drift
# detection account for everything actually published rather than only the part
# that arrived on the command line.
function effective_ports() {
    local path port file
    path="$1"

    for port in ${PARSED_PORTS[@]+"${PARSED_PORTS[@]}"}; do
        printf '%s\n' "$port"
    done

    file="$(devcontainer_path "$path")"
    if [ -f "$file" ]; then
        devcontainer_forward_ports "$file"
    fi
}

# Comma-joins stdin, dropping blanks and repeats. Publishing the same port twice
# makes Podman fail outright, so a devcontainer port already named by --port must
# collapse into one entry rather than being added again.
function join_unique() {
    local value joined=""
    while IFS= read -r value; do
        [ -n "$value" ] || continue
        case ",${joined}," in
            *",${value},"*)
                continue
                ;;
        esac
        joined="${joined:+${joined},}${value}"
    done
    printf '%s\n' "$joined"
}

# Parses CLI options into the PARSED_* globals, then delegates. Callers that
# have already parsed (e.g. shell) invoke start_container directly so options
# are never parsed twice.
function start() {
    parse_project_args "$@"
    local parse_status=$?
    # 2 means --help was handled and printed; that is a successful invocation.
    if [ "$parse_status" -eq 2 ]; then
        return 0
    fi
    if [ "$parse_status" -ne 0 ]; then
        return "$parse_status"
    fi

    start_container
}

function start_container() {
    local path name host_auth recreate network port_list
    path="$(resolve_project_path "$PARSED_PATH")" || return 1
    name="$(get_container_name "$path")" || return 1
    host_auth="$PARSED_HOST_AUTH"
    recreate="$PARSED_RECREATE"
    network="$PARSED_NETWORK"
    # Computed before run_args so devcontainer forwardPorts reach the label and
    # the -p flags together, instead of being published but never recorded.
    port_list="$(effective_ports "$path" | join_unique)"

    require_podman || return 1

    if container_exists "$name"; then
        verify_project_identity "$name" "$path" || return 1
    fi

    if [ "$recreate" = "1" ]; then
        if ! image_exists; then
            echo "Error: Sandbox image '$IMAGE_NAME' not found." >&2
            echo "Please run: $(command_name) build" >&2
            return 1
        fi
        remove_existing_container "$name"
    elif container_exists "$name"; then
        fail_if_stale "$name" "$path" || return 1
        warn_option_drift "$name" "$host_auth" "$network" "$port_list"

        if container_running "$name"; then
            echo "Sandbox '$name' is already running."
            seed_existing_container "$name"
            return 0
        fi

        echo "Starting existing sandbox '$name'..."
        podman start "$name" >/dev/null || return 1
        seed_existing_container "$name"
        return 0
    fi

    if ! image_exists; then
        echo "Error: Sandbox image '$IMAGE_NAME' not found." >&2
        echo "Please run: $(command_name) build" >&2
        return 1
    fi

    echo "Starting new sandbox for $path..."

    create_volume "${name}-build" "$path" || return 1
    create_volume "${name}-deps" "$path" || return 1
    create_volume "${name}-mise" "$path" || return 1

    local sandbox_dir dotfiles_dir
    sandbox_dir="$(script_dir)" || return 1
    dotfiles_dir="$(cd "$sandbox_dir/../.." && pwd -P)" || return 1

    local run_args=(
        -d
        --init
        --label "sandbox.project=${path}"
        --label "sandbox.host-auth=${host_auth}"
        --label "sandbox.network=${network}"
        --label "sandbox.ports=${port_list}"
        --name "$name"
        -v "${name}-build:/workspace/_build"
        -v "${name}-deps:/workspace/deps"
        -v "${name}-mise:${CONTAINER_MISE_DIR}"
    )

    if [ "$MEMORY_LIMIT" != "0" ]; then
        run_args+=(--memory "$MEMORY_LIMIT")
    fi

    if [ "$PIDS_LIMIT" != "0" ]; then
        run_args+=(--pids-limit "$PIDS_LIMIT")
    fi

    if [ -n "$network" ]; then
        run_args+=(--network "$network")
    fi

    local published
    for published in ${port_list//,/ }; do
        [ -n "$published" ] || continue
        run_args+=(-p "127.0.0.1:${published}:${published}")
    done

    # Rootless Podman on Linux maps the host user to container root by default,
    # leaving /workspace unwritable for the in-container user. Map the host
    # user onto the image user's uid/gid instead — SANDBOX_UID/SANDBOX_GID,
    # matching the image's build args rather than a hardcoded 1000. macOS
    # handles this via the machine VM.
    if [ "$(uname -s)" = "Linux" ]; then
        run_args+=("--userns=keep-id:uid=${CONTAINER_UID},gid=${CONTAINER_GID}")
    fi

    local chown_paths=(
        "/workspace/_build"
        "/workspace/deps"
        "$CONTAINER_MISE_DIR"
    )

    # Claude and Gemini ship in the image; Pi does not (it has no pinned public
    # package), but this repo syncs Pi config, so its state directory is still
    # isolated per project for anyone who installs it inside the sandbox.
    local state_names=(claude gemini pi)
    local host_sources=("${HOME}/.claude" "${HOME}/.gemini" "${HOME}/.pi")
    local state_targets=("${CONTAINER_HOME}/.claude" "${CONTAINER_HOME}/.gemini" "${CONTAINER_HOME}/.pi")

    if [ "$host_auth" = "1" ]; then
        warn_host_auth
        # Claude Code keeps state outside ~/.claude as well.
        if [ -f "${HOME}/.claude.json" ]; then
            run_args+=(-v "$(bind_mount_spec "${HOME}/.claude.json" "${CONTAINER_HOME}/.claude.json" rw)")
        fi
    fi

    local i
    for i in "${!state_names[@]}"; do
        if [ "$host_auth" = "1" ] && [ -e "${host_sources[$i]}" ]; then
            run_args+=(-v "$(bind_mount_spec "${host_sources[$i]}" "${state_targets[$i]}" rw)")
        else
            create_volume "${name}-${state_names[$i]}" "$path" || return 1
            run_args+=(-v "${name}-${state_names[$i]}:${state_targets[$i]}")
            chown_paths+=("${state_targets[$i]}")
        fi
    done

    # Shared agent config is streamed in by seed_agent_config after the container
    # starts, so the dotfiles repo is deliberately NOT mounted here.

    if [ -f "${HOME}/.gitconfig" ]; then
        run_args+=(-v "$(bind_mount_spec "${HOME}/.gitconfig" "${CONTAINER_HOME}/.gitconfig" ro)")
    fi

    if [ -f "${HOME}/.gitignore_global" ]; then
        run_args+=(-v "$(bind_mount_spec "${HOME}/.gitignore_global" "${CONTAINER_HOME}/.gitignore_global" ro)")
    fi

    run_args+=(-v "$(bind_mount_spec "$path" "/workspace" rw)")

    # .env.sandbox can be committed by the repository, so never load it silently.
    # Only variable names are echoed; values may be secrets. Unlike devcontainer
    # mounts these cannot reach host files, so listing them is enough — no prompt.
    if [ -f "${path}/.env.sandbox" ]; then
        if truthy "${SANDBOX_ENV_FILE:-1}"; then
            echo "Loading environment from .env.sandbox:"
            local env_line
            while IFS= read -r env_line || [ -n "$env_line" ]; do
                # Trim leading whitespace so indented entries and comments are
                # classified correctly. Display only — Podman parses the file.
                env_line="${env_line#"${env_line%%[![:space:]]*}"}"
                case "$env_line" in
                    ''|'#'*)
                        continue
                        ;;
                esac
                echo "    ${env_line%%=*}"
            done < "${path}/.env.sandbox"
            run_args+=(--env-file "${path}/.env.sandbox")
        else
            echo "Skipping .env.sandbox (SANDBOX_ENV_FILE=0)."
        fi
    fi

    # Basic devcontainer.json support. Its forwardPorts were already folded into
    # port_list above and published with everything else; what is left here is
    # reporting them and handling mounts, which need confirmation.
    local devcontainer_json
    devcontainer_json="$(devcontainer_path "$path")"
    if [ -f "$devcontainer_json" ]; then
        echo "Detected .devcontainer/devcontainer.json (parsing limited features)..."

        local forwarded
        forwarded="$(devcontainer_forward_ports "$devcontainer_json" | join_unique)"
        if [ -n "$forwarded" ]; then
            echo "  Forwarding ports: $forwarded"
        fi

        if ! command -v jq >/dev/null 2>&1; then
            echo "  jq is not installed — read forwardPorts only, ignoring any mounts."
        elif ! devcontainer_as_json "$devcontainer_json" >/dev/null; then
            echo "  Warning: devcontainer.json did not parse even after JSONC normalization."
            echo "  Ports were recovered approximately; any mounts are ignored."
        fi

        # mounts come from the (possibly untrusted) repository itself, so they
        # can point anywhere on the host. Never apply them silently.
        local mounts
        mounts="$(devcontainer_mount_specs "$devcontainer_json")"
        if [ -n "$mounts" ]; then
            local apply_mounts m answer
            apply_mounts=0

            if truthy "${SANDBOX_APPLY_DEVCONTAINER_MOUNTS:-0}"; then
                apply_mounts=1
            elif [ -t 0 ] && [ -t 1 ]; then
                echo "  devcontainer.json requests host mounts:"
                while IFS= read -r m; do
                    [ -n "$m" ] && echo "    $m"
                done <<< "$mounts"
                printf '  Apply these mounts? They can expose host files to the sandbox. [y/N] '
                read -r answer
                case "$answer" in
                    y|Y|yes|YES)
                        apply_mounts=1
                        ;;
                esac
            fi

            if [ "$apply_mounts" = "1" ]; then
                while IFS= read -r m; do
                    if [ -n "$m" ]; then
                        echo "  Adding mount: $m"
                        run_args+=(--mount "$m")
                    fi
                done <<< "$mounts"
            else
                echo "  Skipping devcontainer mounts (confirm interactively or set SANDBOX_APPLY_DEVCONTAINER_MOUNTS=1)."
            fi
        fi
    fi

    if ! podman run "${run_args[@]}" "$IMAGE_NAME" >/dev/null; then
        echo "Error: Failed to start Podman container." >&2
        return 1
    fi

    echo "Waiting for sandbox '$name' to be ready..."
    local retry=0
    while ! podman exec "$name" true >/dev/null 2>&1; do
        if [ $retry -ge 10 ]; then
            abort_partial_start "$name" "Sandbox failed to become ready."
            return 1
        fi
        sleep 0.5
        retry=$((retry + 1))
    done

    echo "Sandbox '$name' is running."
    echo "Preparing sandbox-owned volumes..."
    if ! podman exec --user root "$name" chown -R "${CONTAINER_USER}:${CONTAINER_USER}" "${chown_paths[@]}"; then
        abort_partial_start "$name" "Failed to prepare sandbox volume ownership."
        return 1
    fi

    seed_agent_config "$name" "$dotfiles_dir" "$host_auth"

    # Toolchain builds (Erlang in particular) fail for reasons that are only
    # debuggable from inside the sandbox — a missing header, no network, a bad
    # .tool-versions pin. Never let that failure deny access to the shell.
    echo "Initializing tools with mise (this may take a moment)..."
    if ! podman exec "$name" bash -lc "/usr/local/bin/mise install"; then
        cat >&2 <<MISE
Warning: 'mise install' did not complete successfully.
The sandbox is running. Open a shell and re-run 'mise install' to see the error.
MISE
    fi

    return 0
}

function recreate() {
    start --recreate "$@"
}

function shell() {
    parse_project_args "$@"
    local parse_status=$?
    if [ "$parse_status" -eq 2 ]; then
        return 0
    fi
    if [ "$parse_status" -ne 0 ]; then
        return "$parse_status"
    fi

    local path name
    path="$(resolve_project_path "$PARSED_PATH")" || return 1
    name="$(get_container_name "$path")" || return 1

    require_podman || return 1

    if container_exists "$name"; then
        verify_project_identity "$name" "$path" || return 1
    fi

    # start_container reads the PARSED_* globals set above, so options are not
    # parsed a second time here.
    if [ "$PARSED_RECREATE" = "1" ] || ! container_running "$name"; then
        start_container || return 1
    else
        warn_if_stale "$name" "$path"
        warn_option_drift "$name" "$PARSED_HOST_AUTH" "$PARSED_NETWORK" \
            "$(effective_ports "$path" | join_unique)"
        # Bare 'sandbox' is this tool's primary entry point, so it keeps the
        # same promise as 'start': config added upstream arrives even when the
        # container has been running for days. Seeding copies only absent
        # files, so this costs two quick execs and overwrites nothing.
        seed_existing_container "$name"
    fi

    local exec_args=(-i)
    if [ -t 0 ] && [ -t 1 ]; then
        exec_args=(-it)
    fi

    podman exec "${exec_args[@]}" "$name" bash
}

# Runs one command inside the project's sandbox and propagates its exit status.
# 'shell' only ever gives an interactive Bash, which makes the sandbox unusable
# from scripts or from an agent driving it on the host: 'sandbox exec mix test'
# is the natural call for a tool built to run agents.
function exec_in_sandbox() {
    local path create
    path="."
    create=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -C|--path)
                shift
                if [ "$#" -eq 0 ]; then
                    echo "Error: -C requires a path." >&2
                    return 1
                fi
                path="$1"
                shift
                ;;
            --create)
                create=1
                shift
                ;;
            -h|--help)
                usage
                return 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                # Without this, a typo'd flag silently becomes the in-container
                # command and fails with a confusing "command not found" there.
                echo "Error: Unknown exec option: $1" >&2
                echo "Use '--' before a command that starts with '-'." >&2
                return 1
                ;;
            *)
                break
                ;;
        esac
    done

    if [ "$#" -eq 0 ]; then
        echo "Error: Please specify a command to run." >&2
        echo "Usage: $(command_name) exec [-C|--path path] [--] <command> [args...]" >&2
        return 1
    fi

    local resolved name
    resolved="$(resolve_project_path "$path")" || return 1
    name="$(get_container_name "$resolved")" || return 1

    require_podman || return 1

    if container_exists "$name"; then
        verify_project_identity "$name" "$resolved" || return 1
    fi

    if container_running "$name"; then
        fail_if_stale "$name" "$resolved" || return 1
        # No re-seeding here, deliberately, unlike start/shell into a running
        # container: exec is the scripted fast path, and two extra podman
        # execs per command is real overhead in a loop. Config added upstream
        # still lands on the next 'start' or 'shell'.
    elif container_exists "$name" || [ "$create" = "1" ]; then
        # Reuse the normal parser so the PARSED_* globals start from their
        # documented defaults rather than being hand-set here.
        parse_project_args "$resolved" || return 1
        start_container || return 1
    else
        # A stopped sandbox is restarted above, but a missing one is not built
        # implicitly: exec is the scriptable entry point, and a typo'd -C path
        # would otherwise spend minutes creating a fresh sandbox only to run
        # the command in an empty workspace.
        echo "Error: No sandbox exists for $resolved." >&2
        echo "Run '$(command_name) start \"$resolved\"' first, or re-run with --create." >&2
        return 1
    fi

    local exec_args=(-i)
    if [ -t 0 ] && [ -t 1 ]; then
        exec_args=(-it)
    fi

    # %q keeps arguments intact through the extra shell needed for mise shims.
    local quoted
    quoted="$(printf '%q ' "$@")"
    podman exec "${exec_args[@]}" "$name" bash -lc "$quoted"
}

function stop() {
    # 'stop --all' stops every running sandbox: without it the only options are
    # one 'stop' per project or the destructive 'clean', while idle sandboxes
    # run 'sleep infinity' indefinitely (holding VM memory on macOS).
    if [ "${1:-}" = "--all" ]; then
        shift
        parse_no_args "stop --all" "$@"
        local all_status=$?
        if [ "$all_status" -eq 2 ]; then
            return 0
        fi
        if [ "$all_status" -ne 0 ]; then
            return "$all_status"
        fi

        require_podman || return 1

        local running=() line
        while IFS= read -r line; do
            running+=("$line")
        done < <(podman ps --filter "name=${SANDBOX_NAME_FILTER}" --format "{{.Names}}")

        if [ "${#running[@]}" -eq 0 ]; then
            echo "No running sandboxes."
            return 0
        fi

        podman stop "${running[@]}" >/dev/null
        printf 'Stopped %s.\n' "${running[@]}"
        return 0
    fi

    parse_path_only stop "$@"
    local parse_status=$?
    if [ "$parse_status" -eq 2 ]; then
        return 0
    fi
    if [ "$parse_status" -ne 0 ]; then
        return "$parse_status"
    fi

    local path name
    path="$(resolve_project_path "$PARSED_PATH")" || return 1
    name="$(get_container_name "$path")" || return 1

    require_podman || return 1

    if container_exists "$name"; then
        verify_project_identity "$name" "$path" || return 1
        podman stop "$name" >/dev/null
        echo "Sandbox '$name' stopped."
    else
        echo "No sandbox found for $path."
    fi
}

# Removes ONE project's sandbox container and volumes. 'stop' keeps everything,
# 'prune' keeps volumes while their project exists, and 'clean' removes every
# project's — so "reset this project's corrupted _build volume or botched
# toolchain" had no command and meant hand-typing generated volume names.
# Volumes are matched by container-name prefix but removed only when their
# sandbox.project label names this project (or is absent — pre-labeling
# volumes reachable only from this exact name): a hash-collided neighbor's
# volumes are reported and kept, never deleted.
function rm_sandbox() {
    local force=0 saw_path=0 input="."

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -f|--force)
                force=1
                ;;
            -h|--help)
                usage
                return 0
                ;;
            --)
                shift
                if [ "$#" -gt 0 ]; then
                    if [ "$saw_path" -eq 1 ]; then
                        echo "Error: Too many project paths provided." >&2
                        return 1
                    fi
                    input="$1"
                    saw_path=1
                    shift
                fi
                if [ "$#" -gt 0 ]; then
                    echo "Error: Too many project paths provided." >&2
                    return 1
                fi
                break
                ;;
            --*)
                echo "Error: Unknown rm option: $1" >&2
                echo "Usage: $(command_name) rm [--force] [path]" >&2
                return 1
                ;;
            *)
                if [ "$saw_path" -eq 1 ]; then
                    echo "Error: Too many project paths provided." >&2
                    return 1
                fi
                input="$1"
                saw_path=1
                ;;
        esac
        shift
    done

    local path name
    path="$(resolve_project_path "$input")" || return 1
    name="$(get_container_name "$path")" || return 1

    require_podman || return 1

    local have_container=0
    if container_exists "$name"; then
        verify_project_identity "$name" "$path" || return 1
        have_container=1
    fi

    # Prefix-match volumes in shell for the same reason as sandbox_volumes:
    # deletion must never depend on the volume filter's unclear semantics.
    local volumes=() skipped=() volume label
    while IFS= read -r volume; do
        case "$volume" in
            "${name}-"*) ;;
            *) continue ;;
        esac
        label="$(volume_label "$volume")"
        if [ -n "$label" ] && [ "$label" != "$path" ]; then
            skipped+=("$volume")
        else
            volumes+=("$volume")
        fi
    done < <(podman volume ls --format "{{.Name}}")

    if [ "${#skipped[@]}" -gt 0 ]; then
        echo "Warning: keeping volumes that belong to a different project (hash collision):" >&2
        printf '  %s\n' "${skipped[@]}" >&2
    fi

    if [ "$have_container" -eq 0 ] && [ "${#volumes[@]}" -eq 0 ]; then
        echo "No sandbox found for $path."
        return 0
    fi

    if [ "$force" -ne 1 ]; then
        if [ ! -t 0 ]; then
            echo "Error: 'rm' removes the sandbox container AND its volumes (build caches, agent state)." >&2
            echo "Re-run with --force to confirm in non-interactive sessions." >&2
            return 1
        fi

        echo "About to remove:"
        if [ "$have_container" -eq 1 ]; then
            echo "  container: $name"
        fi
        for volume in ${volumes[@]+"${volumes[@]}"}; do
            echo "  volume:    $volume"
        done

        local answer
        printf 'Remove this sandbox and its volumes (including agent state)? [y/N] '
        read -r answer
        case "$answer" in
            y|Y|yes|YES)
                ;;
            *)
                echo "Aborted."
                return 1
                ;;
        esac
    fi

    remove_existing_container "$name"

    if [ "${#volumes[@]}" -gt 0 ]; then
        echo "Removing sandbox volumes..."
        podman volume rm "${volumes[@]}"
    fi
}

# Podman's container name filter is a documented regex, but the volume filter's
# matching is less clearly specified (Docker's is substring-only, where '^sbx-'
# matches nothing). Prefix-match in shell so deletion never depends on it.
function sandbox_volumes() {
    local volume
    podman volume ls --format "{{.Name}}" | while IFS= read -r volume; do
        case "$volume" in
            "${CONTAINER_PREFIX}-"*)
                printf '%s\n' "$volume"
                ;;
        esac
    done
}

function prune() {
    parse_no_args prune "$@"
    local parse_status=$?
    if [ "$parse_status" -eq 2 ]; then
        return 0
    fi
    if [ "$parse_status" -ne 0 ]; then
        return "$parse_status"
    fi

    require_podman || return 1

    # Snapshot volumes referenced by ANY sandbox container (running or stopped)
    # BEFORE removing containers. Volume names are deterministic per project
    # path, so keeping a pruned sandbox's volumes preserves its build caches
    # and agent state for the next start.
    local all_ids=()
    local line
    while IFS= read -r line; do
        all_ids+=("$line")
    done < <(podman ps -a --filter "name=${SANDBOX_NAME_FILTER}" --format "{{.ID}}")

    local referenced=""
    if [[ ${#all_ids[@]} -gt 0 ]]; then
        referenced="$(podman inspect "${all_ids[@]}" --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{"\n"}}{{end}}{{end}}' 2>/dev/null)"
    fi

    # status=created covers containers whose 'podman run' failed partway: they
    # never ran, so 'status=exited' alone would leave them behind forever.
    local containers=()
    while IFS= read -r line; do
        containers+=("$line")
    done < <(podman ps -a --filter "name=${SANDBOX_NAME_FILTER}" \
        --filter "status=exited" --filter "status=created" --format "{{.ID}}")

    if [[ ${#containers[@]} -gt 0 ]]; then
        echo "Removing stopped sandbox containers..."
        podman rm "${containers[@]}"
    fi

    local volume project removed_any=0
    while IFS= read -r volume; do
        [ -n "$volume" ] || continue
        if grep -Fxq "$volume" <<< "$referenced"; then
            continue
        fi
        # Unreferenced is not the same as orphaned: this very command removes
        # stopped containers, so their volumes are unreferenced by the NEXT
        # prune — which would then delete the caches and agent state the
        # previous one promised to keep. The volume's own label records the
        # project it belongs to; only when that directory is gone is the
        # volume truly an orphan. Unlabeled volumes (or a label that cannot
        # be read) are kept — 'clean' is the command that removes those.
        project="$(volume_label "$volume")"
        if [ -z "$project" ] || [ -e "$project" ]; then
            continue
        fi
        if [ "$removed_any" -eq 0 ]; then
            echo "Removing orphaned sandbox volumes..."
            removed_any=1
        fi
        podman volume rm "$volume" 2>/dev/null || true
    done < <(sandbox_volumes)
}

function clean() {
    local force=0

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -f|--force)
                force=1
                ;;
            -h|--help)
                usage
                return 0
                ;;
            *)
                echo "Error: Unknown clean option: $1" >&2
                return 1
                ;;
        esac
        shift
    done

    require_podman || return 1

    if [ "$force" -ne 1 ]; then
        if [ ! -t 0 ]; then
            echo "Error: 'clean' removes ALL sandbox containers and volumes, including agent state." >&2
            echo "Re-run with --force to confirm in non-interactive sessions." >&2
            return 1
        fi

        local answer
        printf 'Remove ALL sandbox containers and volumes (including agent state)? [y/N] '
        read -r answer
        case "$answer" in
            y|Y|yes|YES)
                ;;
            *)
                echo "Aborted."
                return 1
                ;;
        esac
    fi

    local running=()
    while IFS= read -r line; do
        running+=("$line")
    done < <(podman ps --filter "name=${SANDBOX_NAME_FILTER}" --format "{{.ID}}")

    if [[ ${#running[@]} -gt 0 ]]; then
        echo "Stopping running sandboxes..."
        podman stop "${running[@]}"
    fi

    local all=()
    while IFS= read -r line; do
        all+=("$line")
    done < <(podman ps -a --filter "name=${SANDBOX_NAME_FILTER}" --format "{{.ID}}")

    if [[ ${#all[@]} -gt 0 ]]; then
        echo "Removing sandbox containers..."
        podman rm "${all[@]}"
    fi

    local volumes=()
    while IFS= read -r line; do
        volumes+=("$line")
    done < <(sandbox_volumes)

    if [[ ${#volumes[@]} -gt 0 ]]; then
        echo "Removing sandbox volumes..."
        podman volume rm "${volumes[@]}"
    fi
}

function list() {
    parse_no_args list "$@"
    local parse_status=$?
    if [ "$parse_status" -eq 2 ]; then
        return 0
    fi
    if [ "$parse_status" -ne 0 ]; then
        return "$parse_status"
    fi

    require_podman || return 1

    # The network/ports/auth labels are maintained precisely (drift detection
    # depends on them), so show them: "what is this container exposing, and
    # does it hold my real credentials?" should not need podman inspect.
    # Empty labels are rendered as "-" template-side — read collapses runs of
    # tabs, so an empty field would shift every column after it.
    local rows
    rows="$(podman ps -a --filter "name=${SANDBOX_NAME_FILTER}" --format '{{.Names}}\t{{.State}}\t{{with index .Labels "sandbox.network"}}{{.}}{{else}}-{{end}}\t{{with index .Labels "sandbox.ports"}}{{.}}{{else}}-{{end}}\t{{with index .Labels "sandbox.host-auth"}}{{.}}{{else}}-{{end}}\t{{index .Labels "sandbox.project"}}')"

    if [ -z "$rows" ]; then
        echo "No sandboxes found."
        return 0
    fi

    local name state network ports auth project stale
    {
        printf 'NAME\tSTATE\tSTALE\tNETWORK\tPORTS\tAUTH\tPROJECT\n'
        while IFS=$'\t' read -r name state network ports auth project; do
            [ -n "$name" ] || continue
            stale="no"
            if container_is_stale "$name"; then
                stale="yes"
            fi
            case "$auth" in
                1) auth="host" ;;
                0) auth="isolated" ;;
                *) auth="?" ;;
            esac
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "$name" "$state" "$stale" "${network:--}" "${ports:--}" "$auth" "${project:-?}"
        done <<< "$rows"
    } | align_table
}

# Raw tabs parse fine but read ragged; 'column -t' lines the table up when
# available (util-linux and BSD both ship it, but it is not POSIX-guaranteed).
function align_table() {
    if command -v column >/dev/null 2>&1; then
        column -t -s $'\t'
    else
        cat
    fi
}

function validate_port() {
    local port port_number
    port="$1"

    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo "Error: Port must be a number between 1 and 65535." >&2
        return 1
    fi

    port_number=$((10#$port))
    if (( port_number < 1 || port_number > 65535 )); then
        echo "Error: Port must be a number between 1 and 65535." >&2
        return 1
    fi
}

function expose() {
    # Recognized in any position, not only first — every other subcommand
    # honors a trailing --help, and expose should not be the odd one out.
    local arg
    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                usage
                return 0
                ;;
        esac
    done

    local port path name
    port="${1:-}"

    if [ -z "$port" ]; then
        echo "Error: Please specify a port to expose." >&2
        echo "Usage: $(command_name) expose <port> [path]" >&2
        return 1
    fi

    validate_port "$port" || return 1

    if [ "$#" -gt 2 ]; then
        echo "Error: Too many arguments." >&2
        echo "Usage: $(command_name) expose <port> [path]" >&2
        return 1
    fi

    path="$(resolve_project_path "${2:-.}")" || return 1
    name="$(get_container_name "$path")" || return 1

    require_command socat "Run './install.sh --with-deps' from the dotfiles repo." || return 1
    require_podman || return 1

    if ! container_running "$name"; then
        echo "Error: Sandbox '$name' is not running." >&2
        return 1
    fi

    verify_project_identity "$name" "$path" || return 1

    # Every inbound connection spawns a `podman exec`, which is noticeably slow
    # for connection-heavy apps (LiveView sockets plus asset requests). Publishing
    # the port at creation time avoids the relay entirely.
    echo "Exposing sandbox port $port to http://localhost:$port ..."
    echo "Tip: '$(command_name) recreate --port $port' publishes it directly and is faster."
    echo "Press Ctrl+C to stop."

    socat TCP-LISTEN:"$port",bind=127.0.0.1,reuseaddr,fork EXEC:"podman exec -i $name nc localhost $port"
}

# Sourcing this file yields its functions without dispatching a command. That is
# how the test suite runs the seed payloads against a real directory: their whole
# job happens inside the container, where a stubbed 'podman exec' sees nothing but
# an opaque script on stdin. Adds no configuration — 'return' outside a function
# only succeeds when sourced.
if (return 0 2>/dev/null); then
    return 0
fi

case "${1:-}" in
    build)
        shift
        build "$@"
        ;;
    start)
        shift
        start "$@"
        ;;
    shell)
        shift
        shell "$@"
        ;;
    exec)
        shift
        exec_in_sandbox "$@"
        ;;
    recreate)
        shift
        recreate "$@"
        ;;
    stop)
        shift
        stop "$@"
        ;;
    rm)
        shift
        rm_sandbox "$@"
        ;;
    list)
        shift
        list "$@"
        ;;
    prune)
        shift
        prune "$@"
        ;;
    clean)
        shift
        clean "$@"
        ;;
    expose)
        shift
        expose "$@"
        ;;
    help|-h|--help)
        usage
        ;;
    --host-auth|--no-host-auth|--recreate|--port|--port=*|--network|--network=*|--no-network)
        shell "$@"
        ;;
    "")
        shell "."
        ;;
    *)
        # A bare path is shorthand for 'shell <path>'.
        if [ -d "$1" ]; then
            shell "$@"
        else
            echo "Error: Unknown command and not a directory: $1" >&2
            usage
            exit 1
        fi
        ;;
esac
