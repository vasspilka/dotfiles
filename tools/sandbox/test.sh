#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SANDBOX="$SCRIPT_DIR/sandbox.sh"

function fail() {
    echo "not ok - $1" >&2
    exit 1
}

function ok() {
    echo "ok - $1"
}

function assert_success_contains() {
    local description expected output status
    description="$1"
    expected="$2"
    shift 2

    set +e
    output="$("$@" 2>&1)"
    status=$?
    set -e

    if [ "$status" -ne 0 ]; then
        echo "$output" >&2
        fail "$description returned $status"
    fi

    if [[ "$output" != *"$expected"* ]]; then
        echo "$output" >&2
        fail "$description did not contain: $expected"
    fi

    ok "$description"
}

function assert_failure_contains() {
    local description expected output status
    description="$1"
    expected="$2"
    shift 2

    set +e
    output="$("$@" 2>&1)"
    status=$?
    set -e

    if [ "$status" -eq 0 ]; then
        echo "$output" >&2
        fail "$description unexpectedly succeeded"
    fi

    if [[ "$output" != *"$expected"* ]]; then
        echo "$output" >&2
        fail "$description did not contain: $expected"
    fi

    ok "$description"
}

function assert_str_contains() {
    local description haystack needle
    description="$1"
    haystack="$2"
    needle="$3"

    if [[ "$haystack" != *"$needle"* ]]; then
        printf '%s\n' "$haystack" >&2
        fail "$description missing: $needle"
    fi

    ok "$description"
}

function assert_str_not_contains() {
    local description haystack needle
    description="$1"
    haystack="$2"
    needle="$3"

    if [[ "$haystack" == *"$needle"* ]]; then
        printf '%s\n' "$haystack" >&2
        fail "$description unexpectedly contains: $needle"
    fi

    ok "$description"
}

bash -n "$SANDBOX"
ok "sandbox.sh bash syntax"

if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "$SANDBOX"
    ok "sandbox.sh shellcheck"
else
    echo "skip - shellcheck not installed"
fi

assert_success_contains "help output" "Commands:" "$SANDBOX" help
assert_success_contains "help output contains prune" "prune" "$SANDBOX" help
assert_success_contains "help output contains clean" "clean" "$SANDBOX" help
assert_success_contains "help output contains recreate" "recreate" "$SANDBOX" help
assert_success_contains "help output contains list" "List sandbox containers" "$SANDBOX" help
assert_success_contains "expose --help shows usage" "Commands:" "$SANDBOX" expose --help
assert_success_contains "expose --help works in any position" "Commands:" "$SANDBOX" expose 4000 --help
assert_success_contains "rm --help shows usage" "Commands:" "$SANDBOX" rm --help
assert_failure_contains "unknown command" "Usage:" "$SANDBOX" definitely-not-a-command

# --help is a successful invocation for every subcommand, not an error.
for subcommand in start stop shell recreate; do
    assert_success_contains "$subcommand --help exits 0" "Commands:" "$SANDBOX" "$subcommand" --help
done

assert_failure_contains "missing expose port" "Please specify a port" "$SANDBOX" expose
assert_failure_contains "expose rejects extra arguments" "Too many arguments" "$SANDBOX" expose 4000 . extra
assert_failure_contains "--port rejects non-numeric" "Port must be a number" "$SANDBOX" start --port abc
assert_failure_contains "--port requires a value" "--port requires a port number" "$SANDBOX" start --port
assert_failure_contains "--network rejects unknown mode" "Unsupported network mode" "$SANDBOX" start --network bogus
assert_failure_contains "--network requires a value" "--network requires a mode" "$SANDBOX" start --network
assert_failure_contains "SANDBOX_NETWORK is validated" "Unsupported network mode" \
    env SANDBOX_NETWORK=bogus "$SANDBOX" start
assert_failure_contains "non-numeric expose port" "Port must be a number" "$SANDBOX" expose abc
assert_failure_contains "out-of-range expose port" "Port must be a number" "$SANDBOX" expose 65536
assert_failure_contains "build unknown option" "Unknown build option" "$SANDBOX" build --bogus
assert_failure_contains "build missing dns value" "--dns requires a server value" "$SANDBOX" build --dns
assert_failure_contains "clean unknown option" "Unknown clean option" "$SANDBOX" clean --bogus
assert_success_contains "exec --help exits 0" "Commands:" "$SANDBOX" exec --help
assert_success_contains "help documents exec" "Run one command in the sandbox" "$SANDBOX" help
assert_failure_contains "exec without a command" "Please specify a command" "$SANDBOX" exec
assert_failure_contains "exec -C requires a path" "-C requires a path" "$SANDBOX" exec -C
assert_failure_contains "prune rejects stray arguments" "takes no arguments" "$SANDBOX" prune bogus
assert_failure_contains "list rejects stray arguments" "takes no arguments" "$SANDBOX" list bogus
assert_failure_contains "stop rejects creation-time options" "does not accept option" "$SANDBOX" stop --port 4000
# '--' conventionally ends option parsing; what follows is a path even if it
# starts with a dash, so the failure is about the path, not an unknown option.
assert_failure_contains "stop -- treats later args as a path" "must be an existing directory" \
    "$SANDBOX" stop -- --not-a-dir
# A typo'd exec flag is rejected instead of silently becoming the command.
assert_failure_contains "exec rejects unknown options" "Unknown exec option" \
    "$SANDBOX" exec --bogus true
assert_failure_contains "stop --all rejects extra arguments" "takes no arguments" \
    "$SANDBOX" stop --all bogus
assert_failure_contains "build --dns rejects a flag-like value" "--dns requires a server value" \
    "$SANDBOX" build --dns -x
assert_success_contains "help documents stop --all" "stop [--all|path]" "$SANDBOX" help
assert_success_contains "help documents exec --path" "-C|--path" "$SANDBOX" help

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sandbox-test.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
PODMAN_LOG="$TMP_DIR/podman.log"

cat > "$TMP_DIR/podman" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PODMAN_LOG"

case "$1" in
    info)
        exit 0
        ;;
    build)
        exit 0
        ;;
    ps)
        if [[ "$*" == *"status=exited"* ]]; then
            echo "stopped-container"
        elif [[ "$*" == *" -a "* ]] || [[ " $* " == *" -a "* ]]; then
            echo "all-container"
        else
            echo "running-container"
        fi
        exit 0
        ;;
    stop|rm)
        exit 0
        ;;
    inspect)
        exit 0
        ;;
    volume)
        case "$2" in
            create|rm)
                exit 0
                ;;
            ls)
                echo "sbx-test-volume"
                exit 0
                ;;
        esac
        ;;
    *)
        echo "unexpected podman command: $*" >&2
        exit 99
        ;;
esac
STUB
chmod +x "$TMP_DIR/podman"

: > "$PODMAN_LOG"
PODMAN_LOG="$PODMAN_LOG" PATH="$TMP_DIR:$PATH" "$SANDBOX" build >/dev/null
if grep -q -- "--no-cache" "$PODMAN_LOG"; then
    fail "build used --no-cache by default"
fi
ok "build uses Podman cache by default"

: > "$PODMAN_LOG"
PODMAN_LOG="$PODMAN_LOG" PATH="$TMP_DIR:$PATH" "$SANDBOX" build --fresh --dns 8.8.8.8 >/dev/null
grep -q -- "--no-cache" "$PODMAN_LOG" || fail "build --fresh did not pass --no-cache"
grep -q -- "--dns 8.8.8.8" "$PODMAN_LOG" || fail "build --dns did not pass DNS server"
ok "build forwards fresh and DNS options"

assert_success_contains "prune command" "Removing stopped sandbox containers" env PODMAN_LOG="$PODMAN_LOG" PATH="$TMP_DIR:$PATH" "$SANDBOX" prune
assert_success_contains "clean --force command" "Stopping running sandboxes" env PODMAN_LOG="$PODMAN_LOG" PATH="$TMP_DIR:$PATH" "$SANDBOX" clean --force

set +e
output="$(env PODMAN_LOG="$PODMAN_LOG" PATH="$TMP_DIR:$PATH" "$SANDBOX" clean </dev/null 2>&1)"
status=$?
set -e
if [ "$status" -eq 0 ]; then
    fail "clean without --force unexpectedly succeeded non-interactively"
fi
assert_str_contains "clean without --force refuses non-interactively" "$output" "--force"

: > "$PODMAN_LOG"
PODMAN_LOG="$PODMAN_LOG" PATH="$TMP_DIR:$PATH" "$SANDBOX" build --update-agents >/dev/null
grep -q -- "--build-arg AGENT_CLI_EPOCH=" "$PODMAN_LOG" ||
    fail "build --update-agents did not bust the agent CLI layer"
ok "build --update-agents busts the agent CLI cache layer"

# 'prune --help' used to fall straight through to prune() with the flag
# discarded, deleting containers and volumes for someone who asked for usage.
for helpless in prune list; do
    : > "$PODMAN_LOG"
    output="$(env PODMAN_LOG="$PODMAN_LOG" PATH="$TMP_DIR:$PATH" "$SANDBOX" "$helpless" --help 2>&1)" ||
        fail "$helpless --help returned non-zero"
    assert_str_contains "$helpless --help prints usage" "$output" "Commands:"
    if [ -s "$PODMAN_LOG" ]; then
        cat "$PODMAN_LOG" >&2
        fail "$helpless --help invoked podman instead of printing usage"
    fi
    ok "$helpless --help touches no containers"
done

# prune/clean delete whatever the name filter matches, so it must be anchored:
# an unanchored "sbx-" also matches an unrelated "my-sbx-notes".
: > "$PODMAN_LOG"
PODMAN_LOG="$PODMAN_LOG" PATH="$TMP_DIR:$PATH" "$SANDBOX" prune >/dev/null
assert_str_contains "prune anchors the name filter" "$(cat "$PODMAN_LOG")" "name=^sbx-"
: > "$PODMAN_LOG"
PODMAN_LOG="$PODMAN_LOG" PATH="$TMP_DIR:$PATH" "$SANDBOX" clean --force >/dev/null
assert_str_contains "clean anchors the name filter" "$(cat "$PODMAN_LOG")" "name=^sbx-"

# --- Lifecycle tests: assert on the composed 'podman run' arguments ---

LIFECYCLE_BIN="$TMP_DIR/lifecycle-bin"
mkdir -p "$LIFECYCLE_BIN"
# Env-driven stub so individual tests can describe the Podman state they need:
#   STUB_EXISTING / STUB_RUNNING   container names reported by `podman ps`
#   STUB_IMAGE_ID                  current image id
#   STUB_CONTAINER_IMAGE_ID        image id the container was created from
#   STUB_LABEL_*                   values returned for `sandbox.*` labels
#   STUB_VOLUME_LABEL              sandbox.project label reported for volumes
#   STUB_MISE_FAIL=1               make `mise install` fail
#   STUB_VOLUME_FAIL=<name>        make `podman volume create <name>` fail
cat > "$LIFECYCLE_BIN/podman" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PODMAN_LOG"

case "$1" in
    volume)
        # Mirror real Podman: 'volume create' FAILS on a name that already
        # exists (unlike Docker's), and 'volume exists' reports presence.
        # Created names persist in a state file across invocations, like a
        # real volume store — a stub that always let create succeed hid
        # exactly the failure the CLI's exists-check prevents. A name matching
        # STUB_VOLUME_FAIL reports absent so its create is attempted and fails.
        # 'create' takes the volume name as its LAST argument, after --label.
        volume_name="${!#}"
        case "$2" in
            exists)
                if [ -n "${STUB_VOLUME_FAIL:-}" ] && [[ "$volume_name" == *"${STUB_VOLUME_FAIL}" ]]; then
                    exit 1
                fi
                if [ -f "${PODMAN_LOG}.volumes" ] && grep -Fxq "$volume_name" "${PODMAN_LOG}.volumes"; then
                    exit 0
                fi
                exit 1
                ;;
            create)
                if [ -n "${STUB_VOLUME_FAIL:-}" ] && [[ "$volume_name" == *"${STUB_VOLUME_FAIL}" ]]; then
                    echo "Error: volume create failed" >&2
                    exit 125
                fi
                if [ -f "${PODMAN_LOG}.volumes" ] && grep -Fxq "$volume_name" "${PODMAN_LOG}.volumes"; then
                    echo "Error: volume with name \"$volume_name\" already exists" >&2
                    exit 125
                fi
                printf '%s\n' "$volume_name" >> "${PODMAN_LOG}.volumes"
                exit 0
                ;;
            inspect)
                echo "${STUB_VOLUME_LABEL:-}"
                exit 0
                ;;
            ls)
                # Volumes created earlier in the run are the volume store,
                # same state file 'exists' and 'create' maintain.
                if [ -f "${PODMAN_LOG}.volumes" ]; then
                    cat "${PODMAN_LOG}.volumes"
                fi
                exit 0
                ;;
        esac
        exit 0
        ;;
    info|run|start|stop|rm)
        exit 0
        ;;
    exec)
        if [[ "$*" == *"mise install"* ]] && [ "${STUB_MISE_FAIL:-0}" = "1" ]; then
            echo "mise: simulated toolchain build failure" >&2
            exit 1
        fi
        exit 0
        ;;
    image)
        if [ "$2" = "inspect" ]; then
            echo "${STUB_IMAGE_ID:-sha256:stub-image}"
        fi
        exit 0
        ;;
    ps)
        if [[ "$*" == *" -a "* ]]; then
            printf '%s' "${STUB_EXISTING:-}"
            [ -n "${STUB_EXISTING:-}" ] && printf '\n'
        else
            printf '%s' "${STUB_RUNNING:-}"
            [ -n "${STUB_RUNNING:-}" ] && printf '\n'
        fi
        exit 0
        ;;
    inspect)
        case "$*" in
            *sandbox.project*)    echo "${STUB_LABEL_PROJECT:-}" ;;
            *sandbox.host-auth*)  echo "${STUB_LABEL_HOST_AUTH:-}" ;;
            *sandbox.network*)    echo "${STUB_LABEL_NETWORK:-}" ;;
            *sandbox.ports*)      echo "${STUB_LABEL_PORTS:-}" ;;
            *)                    echo "${STUB_CONTAINER_IMAGE_ID:-sha256:stub-image}" ;;
        esac
        exit 0
        ;;
    *)
        echo "unexpected podman command: $*" >&2
        exit 99
        ;;
esac
STUB
chmod +x "$LIFECYCLE_BIN/podman"

FAKE_HOME="$TMP_DIR/home"
PROJECT_A="$TMP_DIR/project-a"
mkdir -p "$FAKE_HOME" "$PROJECT_A"

# sandbox.sh canonicalizes paths (pwd -P); match that so assertions compare equals.
FAKE_HOME="$(cd "$FAKE_HOME" && pwd -P)"
PROJECT_A="$(cd "$PROJECT_A" && pwd -P)"

function run_line() {
    grep '^run ' "$PODMAN_LOG" | tail -n 1
}

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "default start failed"
RUN_ARGS="$(run_line)"
assert_str_contains "start passes --init" "$RUN_ARGS" "--init"
assert_str_contains "start labels the project path" "$RUN_ARGS" "--label sandbox.project=$PROJECT_A"
assert_str_contains "start labels host-auth off by default" "$RUN_ARGS" "--label sandbox.host-auth=0"
assert_str_contains "start mounts project at /workspace" "$RUN_ARGS" "$PROJECT_A:/workspace:rw"
assert_str_contains "start uses isolated claude volume" "$RUN_ARGS" "-claude:/home/developer/.claude"
assert_str_not_contains "start does not mount host claude dir" "$RUN_ARGS" "$FAKE_HOME/.claude:"
assert_str_contains "start caps memory by default" "$RUN_ARGS" "--memory 8g"
assert_str_contains "start caps pids by default" "$RUN_ARGS" "--pids-limit 4096"
# The label is what lets 'prune' tell a volume whose project still exists from
# a true orphan, and what refuses a hash-collided volume reuse.
assert_str_contains "volumes are labeled with their project" "$(cat "$PODMAN_LOG")" \
    "volume create --label sandbox.project=$PROJECT_A"

mkdir -p "$FAKE_HOME/.claude"
touch "$FAKE_HOME/.claude.json"
: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start --host-auth "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "host-auth start failed"
RUN_ARGS="$(run_line)"
assert_str_contains "host-auth mounts host claude dir" "$RUN_ARGS" "$FAKE_HOME/.claude:/home/developer/.claude:rw"
assert_str_contains "host-auth mounts claude.json state" "$RUN_ARGS" "$FAKE_HOME/.claude.json:/home/developer/.claude.json:rw"
assert_str_contains "host-auth labels host-auth on" "$RUN_ARGS" "--label sandbox.host-auth=1"
assert_str_contains "host-auth keeps isolated volume for absent host dirs" "$RUN_ARGS" "-pi:/home/developer/.pi"

if command -v jq >/dev/null 2>&1; then
    PROJECT_B="$TMP_DIR/project-b"
    mkdir -p "$PROJECT_B/.devcontainer"
    PROJECT_B="$(cd "$PROJECT_B" && pwd -P)"
    cat > "$PROJECT_B/.devcontainer/devcontainer.json" <<'JSON'
{
  "forwardPorts": [4000],
  "mounts": ["type=bind,source=/tmp,target=/mnt/host-tmp"]
}
JSON

    : > "$PODMAN_LOG"
    output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
        "$SANDBOX" start "$PROJECT_B" </dev/null 2>&1)" || fail "devcontainer start failed"
    RUN_ARGS="$(run_line)"
    assert_str_contains "devcontainer ports bind to localhost" "$RUN_ARGS" "-p 127.0.0.1:4000:4000"
    assert_str_not_contains "devcontainer mounts are not applied silently" "$RUN_ARGS" "--mount"
    assert_str_contains "devcontainer mount skip is reported" "$output" "Skipping devcontainer mounts"

    # A published port that is not on the label is invisible to 'sandbox list'
    # and to drift detection, which is exactly where someone looks to answer
    # "what is this container exposing?".
    assert_str_contains "devcontainer ports are recorded on the label" "$RUN_ARGS" \
        "--label sandbox.ports=4000"

    # Podman fails outright when the same port is published twice, so a
    # devcontainer port that --port already asked for must collapse into one.
    : > "$PODMAN_LOG"
    env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
        "$SANDBOX" start --port 4000 "$PROJECT_B" </dev/null >/dev/null 2>&1 ||
        fail "devcontainer duplicate port start failed"
    RUN_ARGS="$(run_line)"
    assert_str_contains "overlapping --port and devcontainer port dedupe" "$RUN_ARGS" \
        "--label sandbox.ports=4000"
    if [ "$(grep -o -- "-p 127.0.0.1:4000:4000" <<< "$RUN_ARGS" | wc -l)" -ne 1 ]; then
        printf '%s\n' "$RUN_ARGS" >&2
        fail "port 4000 was published more than once"
    fi
    ok "a port named twice is published once"

    # --port and forwardPorts both land, in that order.
    : > "$PODMAN_LOG"
    env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
        "$SANDBOX" start --port 5432 "$PROJECT_B" </dev/null >/dev/null 2>&1 ||
        fail "devcontainer combined port start failed"
    RUN_ARGS="$(run_line)"
    assert_str_contains "explicit and devcontainer ports combine on the label" "$RUN_ARGS" \
        "--label sandbox.ports=5432,4000"
    assert_str_contains "explicit port is still published" "$RUN_ARGS" "-p 127.0.0.1:5432:5432"
    assert_str_contains "devcontainer port is still published" "$RUN_ARGS" "-p 127.0.0.1:4000:4000"

    : > "$PODMAN_LOG"
    env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
        SANDBOX_APPLY_DEVCONTAINER_MOUNTS=1 \
        "$SANDBOX" start "$PROJECT_B" </dev/null >/dev/null 2>&1 || fail "devcontainer opt-in start failed"
    RUN_ARGS="$(run_line)"
    assert_str_contains "devcontainer mounts applied when opted in" "$RUN_ARGS" "--mount type=bind,source=/tmp,target=/mnt/host-tmp"

    # devcontainer.json is JSONC in the wild: VS Code's own templates ship
    # comments and trailing commas, which strict jq rejects. The old
    # 2>/dev/null swallowed that — ports and mounts silently vanished exactly
    # when jq WAS installed, while the no-jq grep fallback would have coped.
    PROJECT_D="$TMP_DIR/project-d"
    mkdir -p "$PROJECT_D/.devcontainer"
    PROJECT_D="$(cd "$PROJECT_D" && pwd -P)"
    cat > "$PROJECT_D/.devcontainer/devcontainer.json" <<'JSON'
{
  // line comment
  "$schema": "https://example.test/schema.json", // a "//" inside a string
  "forwardPorts": [4100,],
  /* block
     comment */
  "mounts": ["type=bind,source=/tmp,target=/mnt/host-tmp",],
}
JSON

    : > "$PODMAN_LOG"
    output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
        "$SANDBOX" start "$PROJECT_D" </dev/null 2>&1)" || fail "JSONC devcontainer start failed"
    RUN_ARGS="$(run_line)"
    assert_str_contains "JSONC devcontainer ports are published" "$RUN_ARGS" "-p 127.0.0.1:4100:4100"
    assert_str_contains "JSONC devcontainer ports reach the label" "$RUN_ARGS" "--label sandbox.ports=4100"
    # Mount detection proves the jq path (not the approximate grep one)
    # handled the file: mounts are jq-only, so seeing them means the
    # normalization preserved the "//" inside the $schema string.
    assert_str_contains "JSONC devcontainer mounts are detected and held" "$output" "Skipping devcontainer mounts"
    assert_str_not_contains "a normalizable file draws no parse warning" "$output" "did not parse"

    : > "$PODMAN_LOG"
    env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
        SANDBOX_APPLY_DEVCONTAINER_MOUNTS=1 \
        "$SANDBOX" start "$PROJECT_D" </dev/null >/dev/null 2>&1 || fail "JSONC opt-in start failed"
    assert_str_contains "JSONC devcontainer mounts apply on opt-in" "$(run_line)" \
        "--mount type=bind,source=/tmp,target=/mnt/host-tmp"

    # A file that stays unparseable even after normalization is REPORTED, and
    # ports still recover through the approximate grep path (worst case an
    # extra localhost binding); mounts stay ignored — they are host-path
    # grants, where an approximate parse is not acceptable.
    PROJECT_E="$TMP_DIR/project-e"
    mkdir -p "$PROJECT_E/.devcontainer"
    PROJECT_E="$(cd "$PROJECT_E" && pwd -P)"
    printf '{ "forwardPorts": [4200], "broken": \n' > "$PROJECT_E/.devcontainer/devcontainer.json"

    : > "$PODMAN_LOG"
    output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
        "$SANDBOX" start "$PROJECT_E" </dev/null 2>&1)" || fail "broken devcontainer start failed"
    assert_str_contains "an unparseable devcontainer.json is reported" "$output" "did not parse"
    assert_str_contains "ports still recover approximately" "$(run_line)" "-p 127.0.0.1:4200:4200"
    assert_str_not_contains "mounts from an unparseable file are ignored" "$(run_line)" "--mount"
else
    echo "skip - jq not installed (devcontainer tests)"
fi

# --- Prune keeps volumes of the sandboxes it removes ---
#
# "Unreferenced" must not mean "orphaned": prune itself removes stopped
# containers, so on the NEXT prune their volumes are referenced by nothing —
# and a naive reference check would delete the caches and agent state the
# previous prune promised to keep. Orphanhood comes from the volume's own
# sandbox.project label instead: only a volume whose recorded project
# directory is gone is removed. Unlabeled volumes are kept ('clean' handles
# those). The stub reports labels per volume name:
#   sbx-dead-*      referenced by the stopped container being pruned
#   sbx-gone        unreferenced, project directory deleted    -> removed
#   sbx-alive       unreferenced, project directory still here -> kept
#   sbx-unlabeled   unreferenced, no label                     -> kept
#   my-sbx-notes    not a sandbox volume at all                -> untouched

PRUNE_BIN="$TMP_DIR/prune-bin"
mkdir -p "$PRUNE_BIN"
cat > "$PRUNE_BIN/podman" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PODMAN_LOG"

case "$1" in
    info|rm)
        exit 0
        ;;
    ps)
        echo "deadid"
        exit 0
        ;;
    inspect)
        printf 'sbx-dead-build\nsbx-dead-claude\n'
        exit 0
        ;;
    volume)
        case "$2" in
            ls)
                printf 'sbx-dead-build\nsbx-dead-claude\nsbx-gone\nsbx-alive\nsbx-unlabeled\nmy-sbx-notes\n'
                ;;
            inspect)
                case "$3" in
                    sbx-gone)  echo "$STUB_GONE_PROJECT" ;;
                    sbx-alive) echo "$STUB_ALIVE_PROJECT" ;;
                    *)         echo "" ;;
                esac
                ;;
        esac
        exit 0
        ;;
    *)
        echo "unexpected podman command: $*" >&2
        exit 99
        ;;
esac
STUB
chmod +x "$PRUNE_BIN/podman"

: > "$PODMAN_LOG"
env PODMAN_LOG="$PODMAN_LOG" PATH="$PRUNE_BIN:$PATH" \
    STUB_GONE_PROJECT="$TMP_DIR/deleted-project" STUB_ALIVE_PROJECT="$PROJECT_A" \
    "$SANDBOX" prune >/dev/null || fail "prune scenario failed"
PRUNE_CALLS="$(cat "$PODMAN_LOG")"
assert_str_contains "prune removes stopped containers" "$PRUNE_CALLS" "rm deadid"
assert_str_contains "prune removes a volume whose project is gone" "$PRUNE_CALLS" "volume rm sbx-gone"
assert_str_not_contains "a repeat prune keeps volumes whose project still exists" "$PRUNE_CALLS" "volume rm sbx-alive"
assert_str_not_contains "prune keeps unlabeled volumes" "$PRUNE_CALLS" "volume rm sbx-unlabeled"
assert_str_not_contains "prune keeps pruned sandbox build volume" "$PRUNE_CALLS" "volume rm sbx-dead-build"
assert_str_not_contains "prune keeps pruned sandbox agent state" "$PRUNE_CALLS" "volume rm sbx-dead-claude"
# Volume matching is done by prefix in shell (Podman's volume name filter has
# unclear regex semantics), so a volume merely containing "sbx-" must survive.
assert_str_not_contains "prune leaves non-sandbox volumes alone" "$PRUNE_CALLS" "volume rm my-sbx-notes"
assert_str_contains "prune sweeps created-but-never-started containers" "$PRUNE_CALLS" "status=created"

# --- Container naming is deterministic per project path ---

function name_from_run_line() {
    run_line | sed -n 's/.*--name \([^ ]*\).*/\1/p'
}

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "naming run 1 failed"
NAME_A1="$(name_from_run_line)"
: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "naming run 2 failed"
NAME_A2="$(name_from_run_line)"
[ -n "$NAME_A1" ] || fail "could not extract container name"
[ "$NAME_A1" = "$NAME_A2" ] || fail "same path produced different names: $NAME_A1 vs $NAME_A2"
ok "same project path is stable across runs ($NAME_A1)"

PROJECT_C="$TMP_DIR/project-c"
mkdir -p "$PROJECT_C"
PROJECT_C="$(cd "$PROJECT_C" && pwd -P)"
: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start "$PROJECT_C" </dev/null >/dev/null 2>&1 || fail "distinct path start failed"
NAME_C="$(name_from_run_line)"
[ "$NAME_A1" != "$NAME_C" ] || fail "distinct paths collided on $NAME_A1"
ok "distinct project paths get distinct sandboxes"

# --- Ports are published at creation and recorded on the container ---

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start --port 4000 --port 5432 "$PROJECT_A" </dev/null >/dev/null 2>&1 ||
    fail "--port start failed"
RUN_ARGS="$(run_line)"
assert_str_contains "--port publishes on localhost" "$RUN_ARGS" "-p 127.0.0.1:4000:4000"
assert_str_contains "--port is repeatable" "$RUN_ARGS" "-p 127.0.0.1:5432:5432"
assert_str_contains "--port is recorded as a label" "$RUN_ARGS" "--label sandbox.ports=4000,5432"

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start --port=4000 "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "--port= start failed"
assert_str_contains "--port=N form works" "$(run_line)" "-p 127.0.0.1:4000:4000"

# --- Network mode ---

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start --no-network "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "--no-network failed"
RUN_ARGS="$(run_line)"
assert_str_contains "--no-network cuts egress" "$RUN_ARGS" "--network none"
assert_str_contains "network mode is recorded as a label" "$RUN_ARGS" "--label sandbox.network=none"

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" SANDBOX_NETWORK=none \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "SANDBOX_NETWORK failed"
assert_str_contains "SANDBOX_NETWORK sets the default" "$(run_line)" "--network none"

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "default network start failed"
assert_str_not_contains "no --network flag by default" "$(run_line)" "--network"

# --- Read-only host config mounts ---

touch "$FAKE_HOME/.gitconfig" "$FAKE_HOME/.gitignore_global"
: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "ro mount start failed"
RUN_ARGS="$(run_line)"
assert_str_contains "gitconfig mounts read-only" "$RUN_ARGS" "$FAKE_HOME/.gitconfig:/home/developer/.gitconfig:ro"
assert_str_contains "global gitignore mounts read-only" "$RUN_ARGS" "$FAKE_HOME/.gitignore_global:/home/developer/.gitignore_global:ro"

# Agent config is streamed in over stdin, so the dotfiles repo (which carries
# .claude settings, hooks, and skills) must never be mounted into a sandbox.
assert_str_not_contains "dotfiles repo is never mounted" "$RUN_ARGS" "$(cd "$SCRIPT_DIR/../.." && pwd -P)"

# The only host paths in a sandbox are the project and the two git config files.
HOST_BINDS="$(printf '%s\n' "$RUN_ARGS" | tr ' ' '\n' | grep -c "^$FAKE_HOME" || true)"
[ "$HOST_BINDS" -eq 2 ] || fail "expected exactly 2 host binds, got $HOST_BINDS"
ok "only gitconfig and gitignore_global are bound from HOME"

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" SANDBOX_BIND_EXTRA_OPTIONS=z \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "bind option start failed"
assert_str_contains "SANDBOX_BIND_EXTRA_OPTIONS appends to binds" "$(run_line)" "$PROJECT_A:/workspace:rw,z"

# --- Agent config seeding into isolated volumes ---

: > "$PODMAN_LOG"
output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)" || fail "seed start failed"
assert_str_contains "seeds agent config when isolated" "$output" "Seeding agent config"

: > "$PODMAN_LOG"
output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start --host-auth "$PROJECT_A" </dev/null 2>&1)" || fail "host-auth seed start failed"
assert_str_not_contains "does not seed when host config is mounted" "$output" "Seeding agent config"

# The seeded config must launch the MCP binary the image installs. 'npx -y
# @playwright/mcp' would not: npm exec looks for a global bin named exactly
# "@playwright/mcp" (the real bin is "playwright-mcp"), misses, and falls back to
# a registry fetch — which fails under --network none and otherwise pulls a
# version that can drift from the pinned Playwright browsers.
SEED_BIN="$TMP_DIR/seed-bin"
SEED_HOME="$TMP_DIR/seed-home"
mkdir -p "$SEED_BIN" "$SEED_HOME"
cat > "$SEED_BIN/podman" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PODMAN_LOG"

case "$1" in
    exec)
        # Run the real seeding scripts against a writable stand-in home, so they
        # are exercised end to end with the same bash, tar, and node the
        # container would use. Both payloads share the shape
        #   exec -i <name> bash -c <script> _ <home> <arg>
        # and nothing else the CLI exec's matches it: the ownership fix runs
        # chown, `mise install` uses bash -lc, and a shell is bare bash.
        if [ "$4" = "bash" ] && [ "$5" = "-c" ]; then
            if [ "${STUB_SEED_FAIL:-0}" = "1" ]; then
                echo "simulated seed failure detail" >&2
                exit 1
            fi
            exec bash -c "$6" _ "$SEED_HOME" "${9}"
        fi
        exit 0
        ;;
    info|run|start|stop|rm|volume)
        exit 0
        ;;
    image)
        [ "$2" = "inspect" ] && echo "sha256:stub-image"
        exit 0
        ;;
    ps)
        exit 0
        ;;
    inspect)
        echo "sha256:stub-image"
        exit 0
        ;;
    *)
        echo "unexpected podman command: $*" >&2
        exit 99
        ;;
esac
STUB
chmod +x "$SEED_BIN/podman"

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$SEED_BIN:$PATH" SEED_HOME="$SEED_HOME" \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "seed rewrite start failed"
SEEDED="$(cat "$SEED_HOME/.gemini/settings.json" 2>/dev/null || true)"
assert_str_contains "seeded config launches the image's MCP binary" "$SEEDED" '"command": "playwright-mcp"'
assert_str_not_contains "seeded config does not go through npx" "$SEEDED" "npx"

# In-sandbox edits must survive a restart.
printf '{"edited": true}\n' > "$SEED_HOME/.gemini/settings.json"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$SEED_BIN:$PATH" SEED_HOME="$SEED_HOME" \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "seed rerun failed"
assert_str_contains "seeding never overwrites in-sandbox edits" \
    "$(cat "$SEED_HOME/.gemini/settings.json")" '"edited"'

# --- Claude Code gets the same treatment as Gemini ---
#
# Without this the tool's primary agent starts stock in every sandbox: no global
# instructions, no skills, no permission allowlist. The source is this repo's own
# .claude/, streamed in, so these assert on properties rather than on whatever
# the checked-in files happen to say today.

assert_str_contains "Claude Code config is seeded" \
    "$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$SEED_BIN:$PATH" SEED_HOME="$SEED_HOME" \
        "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)" "Claude Code:"

[ -f "$SEED_HOME/.claude/CLAUDE.md" ] || fail "CLAUDE.md was not seeded"
ok "global instructions reach the sandbox"

[ -d "$SEED_HOME/.claude/skills" ] || fail "skills/ was not seeded"
ok "skills reach the sandbox"

# settings.json is filtered to an allowlist. hooks and statusLine shell out to
# host-only binaries (rtk, cship), so a verbatim copy would fail on every tool
# call; plugin wiring needs registry access that is gone under --network none.
SEEDED_KEYS="$(node -e '
const fs = require("fs");
const file = process.argv[1];
if (!fs.existsSync(file)) { console.log("<absent>"); process.exit(0); }
console.log(Object.keys(JSON.parse(fs.readFileSync(file, "utf8"))).join(","));
' "$SEED_HOME/.claude/settings.json")"
assert_str_contains "seeded settings keep permissions" "$SEEDED_KEYS" "permissions"
assert_str_not_contains "seeded settings drop host-bound hooks" "$SEEDED_KEYS" "hooks"
assert_str_not_contains "seeded settings drop the host status line" "$SEEDED_KEYS" "statusLine"
assert_str_not_contains "seeded settings drop plugin wiring" "$SEEDED_KEYS" "Plugins"
assert_str_not_contains "seeded settings drop marketplace wiring" "$SEEDED_KEYS" "Marketplaces"

# CLAUDE.md @imports siblings that are deliberately not seeded (RTK.md documents
# a host-side hook and binary). A dangling import is worse than a dropped line.
UNRESOLVED=""
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        @*)
            [ -e "$SEED_HOME/.claude/${line#@}" ] || UNRESOLVED="$UNRESOLVED ${line}"
            ;;
    esac
done < "$SEED_HOME/.claude/CLAUDE.md"
[ -z "$UNRESOLVED" ] || fail "seeded CLAUDE.md has unresolved imports:$UNRESOLVED"
ok "seeded CLAUDE.md has no unresolved @imports"

# macOS bsdtar packs xattrs as AppleDouble "._name" members, which GNU tar in the
# container extracts as real files, scattering ._CLAUDE.md through the tree.
if [ "$(find "$SEED_HOME/.claude" -name '._*' | wc -l)" -ne 0 ]; then
    find "$SEED_HOME/.claude" -name '._*' >&2
    fail "AppleDouble files leaked into the seeded tree"
fi
ok "no AppleDouble files in the seeded tree"

# The staging directory the payload extracts through is not left behind.
if [ "$(find "$SEED_HOME/.claude" -name '.seed-staging*' | wc -l)" -ne 0 ]; then
    fail "seed staging directory was left behind"
fi
ok "seed staging directory is cleaned up"

# Same promise as Gemini: in-sandbox edits survive, but a file added upstream
# still arrives. Skipping the whole seed when the directory is non-empty would
# mean a new skill never lands.
printf 'EDITED IN SANDBOX\n' > "$SEED_HOME/.claude/CLAUDE.md"
rm -rf "$SEED_HOME/.claude/skills"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$SEED_BIN:$PATH" SEED_HOME="$SEED_HOME" \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "claude seed rerun failed"
assert_str_contains "Claude seeding never overwrites in-sandbox edits" \
    "$(cat "$SEED_HOME/.claude/CLAUDE.md")" "EDITED IN SANDBOX"
[ -d "$SEED_HOME/.claude/skills" ] || fail "a removed skills/ tree was not re-seeded"
ok "config added upstream still arrives on a later start"

# Symlinks inside .claude (e.g. a skill linking a shared file) must survive
# seeding: tar carries them into staging, and a plain '-type f' walk would drop
# them silently. Run the payload directly against a scratch home — sourcing
# sandbox.sh yields its functions without dispatching a command.
source "$SANDBOX"
LINK_SRC="$TMP_DIR/link-src"
LINK_HOME="$TMP_DIR/link-home"
mkdir -p "$LINK_SRC/skills"
printf 'real\n' > "$LINK_SRC/skills/real.md"
ln -s real.md "$LINK_SRC/skills/alias.md"
COPYFILE_DISABLE=1 tar -cf - -C "$LINK_SRC" skills |
    bash -c "$(claude_seed_script)" _ "$LINK_HOME" '["permissions"]'
[ -L "$LINK_HOME/.claude/skills/alias.md" ] || fail "seeding dropped a symlink"
[ "$(cat "$LINK_HOME/.claude/skills/alias.md")" = "real" ] || fail "seeded symlink does not resolve"
ok "symlinks inside seeded config survive"

# --host-auth mounts the host's real ~/.claude, so seeding must stay out of it.
rm -rf "$SEED_HOME/.claude"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$SEED_BIN:$PATH" SEED_HOME="$SEED_HOME" \
    "$SANDBOX" start --host-auth "$PROJECT_A" </dev/null >/dev/null 2>&1 ||
    fail "host-auth claude seed start failed"
[ ! -e "$SEED_HOME/.claude" ] || fail "host-auth start seeded over the mounted host config"
ok "host-auth start never seeds over mounted host config"

# A failed seed warns AND surfaces the payload's own error: the scripts run
# inside the container, so their stderr is the only diagnostic there is.
output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$SEED_BIN:$PATH" SEED_HOME="$SEED_HOME" \
    STUB_SEED_FAIL=1 "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)" || fail "seed-failure start aborted"
assert_str_contains "a failed seed still warns" "$output" "Could not seed"
assert_str_contains "a failed seed surfaces the underlying error" "$output" "simulated seed failure detail"

# --- .env.sandbox is announced, never silent, and never prints values ---

printf 'SECRET_TOKEN=hunter2\n# a comment\n  # indented comment\n\n  INDENTED=1\nDATABASE_URL=postgres://x\n' > "$PROJECT_A/.env.sandbox"
: > "$PODMAN_LOG"
output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)" || fail ".env.sandbox start failed"
assert_str_contains "env file is announced" "$output" "Loading environment from .env.sandbox"
assert_str_contains "env file lists variable names" "$output" "SECRET_TOKEN"
assert_str_not_contains "env file never prints values" "$output" "hunter2"
assert_str_not_contains "env file skips comments" "$output" "# a comment"
assert_str_contains "env file announces indented entries trimmed" "$output" "INDENTED"
assert_str_not_contains "env file skips indented comments" "$output" "indented comment"
assert_str_contains "env file is passed to podman" "$(run_line)" "--env-file $PROJECT_A/.env.sandbox"

: > "$PODMAN_LOG"
output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" SANDBOX_ENV_FILE=0 \
    "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)" || fail "SANDBOX_ENV_FILE=0 start failed"
assert_str_contains "SANDBOX_ENV_FILE=0 skips the file" "$output" "Skipping .env.sandbox"
assert_str_not_contains "skipped env file is not passed to podman" "$(run_line)" "--env-file"
rm -f "$PROJECT_A/.env.sandbox"

# --- A volume that cannot be created stops the start, and says why ---
#
# Unchecked, this surfaces much later as a 'podman run' error naming a volume the
# user never typed, and only after the run args have been composed.

: > "$PODMAN_LOG"
assert_failure_contains "failed volume create is reported" "Could not create sandbox volume" \
    env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    STUB_VOLUME_FAIL="-mise" "$SANDBOX" start "$PROJECT_A"
assert_str_not_contains "failed volume create never reaches podman run" "$(cat "$PODMAN_LOG")" "run -d"

# Agent-state volumes are created later than the build caches, so cover both.
: > "$PODMAN_LOG"
assert_failure_contains "failed agent-state volume is reported" "Could not create sandbox volume" \
    env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    STUB_VOLUME_FAIL="-claude" "$SANDBOX" start "$PROJECT_A"
assert_str_not_contains "failed agent-state volume never reaches podman run" "$(cat "$PODMAN_LOG")" "run -d"

# --- A failing toolchain build must not deny shell access ---

: > "$PODMAN_LOG"
set +e
output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" STUB_MISE_FAIL=1 \
    "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)"
status=$?
set -e
[ "$status" -eq 0 ] || fail "mise failure aborted start (exit $status)"
assert_str_contains "mise failure warns instead of aborting" "$output" "did not complete successfully"
ok "start succeeds even when mise install fails"

# --- But a failed initialization must not leave a container behind ---
#
# 'podman run' has already produced a running container by the time the volume
# ownership fix runs. Leaving it there on failure is worse than having none: its
# volumes are still root-owned and no toolchain is installed, yet every later
# command sees a running container, reports "already running", and hands back a
# shell into it. The readiness loop shares the same cleanup helper.

FAILINIT_BIN="$TMP_DIR/failinit-bin"
FAILINIT_STATE="$TMP_DIR/failinit-state"
mkdir -p "$FAILINIT_BIN" "$FAILINIT_STATE"
cat > "$FAILINIT_BIN/podman" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PODMAN_LOG"

case "$1" in
    run)
        # Record the container name so later 'ps' calls report it as existing,
        # the way a real container does the moment 'podman run' returns.
        name=""
        for ((i = 1; i <= $#; i++)); do
            if [ "${!i}" = "--name" ]; then
                j=$((i + 1))
                name="${!j}"
            fi
        done
        printf '%s' "$name" > "$STUB_STATE/created"
        exit 0
        ;;
    ps)
        [ -f "$STUB_STATE/created" ] && cat "$STUB_STATE/created" && printf '\n'
        exit 0
        ;;
    exec)
        if [[ "$*" == *"chown"* ]]; then
            echo "chown: operation not permitted" >&2
            exit 1
        fi
        exit 0
        ;;
    rm)
        rm -f "$STUB_STATE/created"
        exit 0
        ;;
    info|start|stop|volume)
        exit 0
        ;;
    image)
        [ "$2" = "inspect" ] && echo "sha256:stub-image"
        exit 0
        ;;
    inspect)
        case "$*" in
            *sandbox.project*) cat "$STUB_STATE/project" 2>/dev/null ;;
            *sandbox.*)        : ;;
            *)                 echo "sha256:stub-image" ;;
        esac
        exit 0
        ;;
    *)
        echo "unexpected podman command: $*" >&2
        exit 99
        ;;
esac
STUB
chmod +x "$FAILINIT_BIN/podman"

printf '%s' "$PROJECT_A" > "$FAILINIT_STATE/project"
: > "$PODMAN_LOG"
set +e
output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$FAILINIT_BIN:$PATH" \
    STUB_STATE="$FAILINIT_STATE" "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)"
status=$?
set -e
[ "$status" -ne 0 ] || fail "failed initialization reported success"
ok "failed initialization exits non-zero"
assert_str_contains "ownership failure is reported" "$output" "Failed to prepare sandbox volume ownership"
assert_str_contains "failed init removes the container" "$(cat "$PODMAN_LOG")" "rm sbx-"
assert_str_not_contains "failed init keeps the named volumes" "$(cat "$PODMAN_LOG")" "volume rm"

# With the container gone, the next start builds a fresh one instead of handing
# back a shell into the half-initialized box.
[ -f "$FAILINIT_STATE/created" ] && fail "container survived a failed initialization"
ok "a later start is not handed a half-initialized sandbox"

# --- Linux gets the rootless uid mapping; macOS does not ---

UNAME_BIN="$TMP_DIR/uname-bin"
mkdir -p "$UNAME_BIN"
cp "$LIFECYCLE_BIN/podman" "$UNAME_BIN/podman"
printf '#!/usr/bin/env bash\necho Linux\n' > "$UNAME_BIN/uname"
chmod +x "$UNAME_BIN/uname"
: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$UNAME_BIN:$PATH" \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "linux start failed"
assert_str_contains "Linux maps host user onto developer uid" "$(run_line)" "--userns=keep-id:uid=1000,gid=1000"

# The Dockerfile's SANDBOX_UID/GID build args are honored at run time too — a
# hardcoded 1000 here would silently break write access for an image built
# with a different uid.
: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$UNAME_BIN:$PATH" \
    SANDBOX_UID=1234 SANDBOX_GID=4321 \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "SANDBOX_UID start failed"
assert_str_contains "SANDBOX_UID/GID override the keep-id mapping" "$(run_line)" \
    "--userns=keep-id:uid=1234,gid=4321"

# --- Reusing an existing container ---

STATE_ENV=(HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH")

# The container name is a truncated hash, so a collision must be refused rather
# than silently sharing another project's /workspace and build volumes.
assert_failure_contains "hash collision is refused" "already belongs to a different project" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="/some/other/project" \
    "$SANDBOX" start "$PROJECT_A"

assert_failure_contains "collision message names both projects" "$PROJECT_A" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="/some/other/project" \
    "$SANDBOX" start "$PROJECT_A"

# Volumes outlive containers, so the same collision can bite with no container
# at all: a collided project would silently share another project's build
# caches and agent state. The volume's own label refuses it.
assert_failure_contains "a hash-collided volume is refused" "already belongs to a different project" \
    env "${STATE_ENV[@]}" STUB_VOLUME_LABEL="/some/other/project" \
    "$SANDBOX" start "$PROJECT_A"

assert_failure_contains "stale container is refused" "created from an older image" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    STUB_IMAGE_ID="sha256:new" STUB_CONTAINER_IMAGE_ID="sha256:old" \
    "$SANDBOX" start "$PROJECT_A"

assert_failure_contains "stale container suggests recreate" "recreate" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    STUB_IMAGE_ID="sha256:new" STUB_CONTAINER_IMAGE_ID="sha256:old" \
    "$SANDBOX" start "$PROJECT_A"

# A *running* stale sandbox still accepts a shell — a rebuild must never lock
# the user away from in-flight work. start/exec keep refusing (tested above).
: > "$PODMAN_LOG"
output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" \
    STUB_IMAGE_ID="sha256:new" STUB_CONTAINER_IMAGE_ID="sha256:old" \
    "$SANDBOX" shell "$PROJECT_A" </dev/null 2>&1)" || fail "shell refused a running stale sandbox"
assert_str_contains "shell warns on a running stale sandbox" "$output" "older image"
assert_str_contains "stale shell still opens bash" "$(cat "$PODMAN_LOG")" "exec -i $NAME_A1 bash"

assert_success_contains "stopped sandbox is restarted" "Starting existing sandbox" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    "$SANDBOX" start "$PROJECT_A"

assert_success_contains "running sandbox is reused" "already running" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" \
    "$SANDBOX" start "$PROJECT_A"

# --- Seeding runs on every start, not only at creation ---
#
# It copies only absent files, so a skill added upstream is one 'sandbox start'
# away — as the README promises — even when the container already exists.

output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    STUB_LABEL_HOST_AUTH="0" \
    "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)" || fail "restart-seed start failed"
assert_str_contains "restarting a stopped sandbox re-seeds config" "$output" "Seeding agent config"

output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" STUB_LABEL_HOST_AUTH="0" \
    "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)" || fail "running-seed start failed"
assert_str_contains "start on a running sandbox re-seeds config" "$output" "Seeding agent config"

# The container's label decides, never the current flags: a sandbox created
# with --host-auth has the real host directories mounted at ~/.claude etc., and
# seeding on a plain restart would write into them.
output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    STUB_LABEL_HOST_AUTH="1" \
    "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)" || fail "host-auth restart failed"
assert_str_not_contains "restart of a host-auth sandbox never seeds" "$output" "Seeding agent config"

# Bare 'sandbox' is the primary entry point and resolves to 'shell', so it must
# keep the same promise: opening a shell into an already-running sandbox still
# delivers config added upstream since the container was created.
output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" STUB_LABEL_HOST_AUTH="0" \
    "$SANDBOX" shell "$PROJECT_A" </dev/null 2>&1)" || fail "running-shell seed failed"
assert_str_contains "shell into a running sandbox re-seeds config" "$output" "Seeding agent config"

output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" STUB_LABEL_HOST_AUTH="1" \
    "$SANDBOX" shell "$PROJECT_A" </dev/null 2>&1)" || fail "host-auth shell failed"
assert_str_not_contains "shell into a host-auth sandbox never seeds" "$output" "Seeding agent config"

# --- Option drift: mount/network/port options only apply at creation ---

output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" STUB_LABEL_HOST_AUTH="0" \
    "$SANDBOX" start --host-auth "$PROJECT_A" 2>&1)"
assert_str_contains "host-auth drift is reported" "$output" "host-auth: 0 -> 1"
assert_str_contains "drift points at recreate" "$output" "recreate"

output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" STUB_LABEL_HOST_AUTH="0" STUB_LABEL_PORTS="" \
    "$SANDBOX" start --port 4000 "$PROJECT_A" 2>&1)"
assert_str_contains "port drift is reported" "$output" "ports: <none> -> 4000"

output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" STUB_LABEL_HOST_AUTH="0" \
    "$SANDBOX" start --no-network "$PROJECT_A" 2>&1)"
assert_str_contains "network drift is reported" "$output" "network: <default> -> none"

output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" STUB_LABEL_HOST_AUTH="0" \
    "$SANDBOX" start "$PROJECT_A" 2>&1)"
assert_str_not_contains "no drift warning when options match" "$output" "different options"

# Drift only fires for explicitly requested options. A plain invocation after
# 'recreate --port 4000' must not nag — following the warning's advice would
# recreate without the port that was deliberately configured.
output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" STUB_LABEL_HOST_AUTH="0" \
    STUB_LABEL_PORTS="4000" STUB_LABEL_NETWORK="none" \
    "$SANDBOX" start "$PROJECT_A" 2>&1)"
assert_str_not_contains "no drift nag for options that were not requested" "$output" "different options"

# A SANDBOX_* variable counts as an explicit request, same as a flag.
output="$(env "${STATE_ENV[@]}" SANDBOX_NETWORK=none STUB_EXISTING="$NAME_A1" \
    STUB_RUNNING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" STUB_LABEL_HOST_AUTH="0" \
    "$SANDBOX" start "$PROJECT_A" 2>&1)"
assert_str_contains "env-set network counts as explicit for drift" "$output" "network: <default> -> none"

# --- recreate replaces the container but keeps volumes ---

: > "$PODMAN_LOG"
env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    "$SANDBOX" recreate "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "recreate failed"
RECREATE_CALLS="$(cat "$PODMAN_LOG")"
assert_str_contains "recreate removes the old container" "$RECREATE_CALLS" "rm $NAME_A1"
assert_str_contains "recreate starts a new container" "$RECREATE_CALLS" "run -d --init"
assert_str_not_contains "recreate never removes volumes" "$RECREATE_CALLS" "volume rm"
# The volumes survived the removed container, and Podman's 'volume create'
# fails on an existing name — so recreate must detect and reuse them, never
# re-create them. The stateful stub errors exactly like real Podman here.
assert_str_contains "recreate checks for surviving volumes" "$RECREATE_CALLS" "volume exists"
assert_str_not_contains "recreate does not re-create surviving volumes" "$RECREATE_CALLS" "volume create"

# --- rm removes one project's sandbox and volumes, and only that project's ---
#
# stop keeps everything, prune keeps volumes while the project exists, and
# clean removes every project's — resetting ONE project's corrupted caches
# previously meant hand-typing generated podman volume names.

rm -f "${PODMAN_LOG}.volumes"
: > "$PODMAN_LOG"
env "${STATE_ENV[@]}" "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "rm-prep start failed"

: > "$PODMAN_LOG"
output="$(env "${STATE_ENV[@]}" "$SANDBOX" rm --help 2>&1)" || fail "rm --help returned non-zero"
assert_str_contains "rm --help prints usage" "$output" "Commands:"
if [ -s "$PODMAN_LOG" ]; then
    cat "$PODMAN_LOG" >&2
    fail "rm --help invoked podman instead of printing usage"
fi
ok "rm --help touches no containers"

assert_failure_contains "rm rejects unknown options" "Unknown rm option" \
    env "${STATE_ENV[@]}" "$SANDBOX" rm --bogus

set +e
output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    STUB_VOLUME_LABEL="$PROJECT_A" "$SANDBOX" rm "$PROJECT_A" </dev/null 2>&1)"
status=$?
set -e
if [ "$status" -eq 0 ]; then
    fail "rm without --force unexpectedly succeeded non-interactively"
fi
assert_str_contains "rm without --force refuses non-interactively" "$output" "--force"

: > "$PODMAN_LOG"
env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    STUB_VOLUME_LABEL="$PROJECT_A" \
    "$SANDBOX" rm --force "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "rm --force failed"
RM_CALLS="$(cat "$PODMAN_LOG")"
grep -Fxq "rm $NAME_A1" "$PODMAN_LOG" || fail "rm did not remove the container"
ok "rm removes the container"
assert_str_contains "rm removes the mise cache volume" "$RM_CALLS" "${NAME_A1}-mise"
assert_str_contains "rm removes isolated agent state" "$RM_CALLS" "${NAME_A1}-claude"

# A hash-collided neighbor's volumes survive rm: matched by name prefix but
# guarded by the sandbox.project label, exactly like create_volume's refusal.
: > "$PODMAN_LOG"
output="$(env "${STATE_ENV[@]}" STUB_VOLUME_LABEL="/some/other/project" \
    "$SANDBOX" rm --force "$PROJECT_A" </dev/null 2>&1)" || fail "rm collision run failed"
assert_str_not_contains "rm keeps a hash-collided neighbor's volumes" "$(cat "$PODMAN_LOG")" "volume rm"
assert_str_contains "rm reports the kept collided volumes" "$output" "different project"

assert_failure_contains "rm refuses a hash-collided container" "already belongs to a different project" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="/some/other/project" \
    "$SANDBOX" rm --force "$PROJECT_A"

assert_success_contains "rm without a sandbox says so" "No sandbox found" \
    env "${STATE_ENV[@]}" "$SANDBOX" rm --force "$PROJECT_C"

# --- stop / list / expose ---

assert_success_contains "stop reports the stopped sandbox" "stopped" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    "$SANDBOX" stop "$PROJECT_A"

assert_success_contains "stop is a no-op without a sandbox" "No sandbox found" \
    env "${STATE_ENV[@]}" "$SANDBOX" stop "$PROJECT_A"

# 'stop --all' is the middle ground between one 'stop' per project and the
# destructive 'clean' — idle sandboxes otherwise run indefinitely.
: > "$PODMAN_LOG"
output="$(env "${STATE_ENV[@]}" STUB_RUNNING="$NAME_A1" \
    "$SANDBOX" stop --all </dev/null 2>&1)" || fail "stop --all failed"
assert_str_contains "stop --all stops every running sandbox" "$(cat "$PODMAN_LOG")" "stop $NAME_A1"
assert_str_contains "stop --all reports what it stopped" "$output" "Stopped $NAME_A1"
assert_str_contains "stop --all anchors the name filter" "$(cat "$PODMAN_LOG")" "name=^sbx-"

assert_success_contains "stop --all with nothing running says so" "No running sandboxes" \
    env "${STATE_ENV[@]}" "$SANDBOX" stop --all

assert_success_contains "list reports no sandboxes when empty" "No sandboxes found" \
    env "${STATE_ENV[@]}" "$SANDBOX" list

# Rows now carry the network/ports/host-auth labels the CLI maintains for
# drift detection — 'what is this container exposing, and does it hold my real
# credentials?' should not need podman inspect.
output="$(env "${STATE_ENV[@]}" \
    STUB_EXISTING="$(printf 'sbx-abc\trunning\t-\t4000\t0\t/work/demo\nsbx-def\trunning\tnone\t-\t1\t/work/other')" \
    "$SANDBOX" list 2>&1)"
assert_str_contains "list prints a header" "$output" "STALE"
assert_str_contains "list prints the project path" "$output" "/work/demo"
assert_str_contains "list shows published ports" "$output" "4000"
assert_str_contains "list shows the network mode" "$output" "none"
assert_str_contains "list marks isolated sandboxes" "$output" "isolated"
assert_str_contains "list marks host-auth sandboxes" "$output" "host"

output="$(env "${STATE_ENV[@]}" \
    STUB_EXISTING="$(printf 'sbx-abc\trunning\t-\t4000\t0\t/work/demo')" \
    STUB_IMAGE_ID="sha256:new" STUB_CONTAINER_IMAGE_ID="sha256:old" \
    "$SANDBOX" list 2>&1)"
assert_str_contains "list flags stale sandboxes" "$output" "yes"

cat > "$LIFECYCLE_BIN/socat" <<'STUB'
#!/usr/bin/env bash
printf 'socat %s\n' "$*" >> "$PODMAN_LOG"
exit 0
STUB
chmod +x "$LIFECYCLE_BIN/socat"
assert_failure_contains "expose refuses a stopped sandbox" "is not running" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" "$SANDBOX" expose 4000 "$PROJECT_A"

# The relay's exact wiring: a localhost-only listener, one podman exec + nc
# per connection. Asserted here because no other test ever reaches socat.
: > "$PODMAN_LOG"
output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" \
    "$SANDBOX" expose 4000 "$PROJECT_A" </dev/null 2>&1)" || fail "expose happy path failed"
SOCAT_LINE="$(grep '^socat ' "$PODMAN_LOG" | tail -n 1)"
assert_str_contains "expose listens on localhost only" "$SOCAT_LINE" \
    "TCP-LISTEN:4000,bind=127.0.0.1,reuseaddr,fork"
assert_str_contains "expose relays through podman exec and nc" "$SOCAT_LINE" \
    "EXEC:podman exec -i $NAME_A1 nc localhost 4000"
assert_str_contains "expose recommends the faster --port path" "$output" "recreate --port 4000"

# --- A bare path is shorthand for 'shell <path>' ---

: > "$PODMAN_LOG"
env "${STATE_ENV[@]}" "$SANDBOX" "$PROJECT_A" </dev/null >/dev/null 2>&1 || fail "bare path failed"
BARE_CALLS="$(cat "$PODMAN_LOG")"
assert_str_contains "bare path starts a sandbox" "$BARE_CALLS" "run -d --init"
assert_str_contains "bare path opens a shell" "$BARE_CALLS" "exec -i $NAME_A1 bash"

# --- exec runs a single command and is usable from scripts ---

: > "$PODMAN_LOG"
env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" \
    "$SANDBOX" exec -C "$PROJECT_A" mix test </dev/null >/dev/null 2>&1 || fail "exec failed"
assert_str_contains "exec runs the command in the sandbox" "$(cat "$PODMAN_LOG")" \
    "exec -i $NAME_A1 bash -lc mix test"

# A bare `podman exec ... bash -lc "$*"` would split this into two arguments.
: > "$PODMAN_LOG"
env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" \
    "$SANDBOX" exec -C "$PROJECT_A" echo "a b" </dev/null >/dev/null 2>&1 || fail "exec quoting failed"
assert_str_contains "exec preserves argument quoting" "$(cat "$PODMAN_LOG")" 'bash -lc echo a\ b'

# '--' lets a command that begins with '-' through; any other leading dash is
# rejected at parse time (tested above) instead of becoming the command.
: > "$PODMAN_LOG"
env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" \
    "$SANDBOX" exec -C "$PROJECT_A" -- --version </dev/null >/dev/null 2>&1 || fail "exec -- failed"
assert_str_contains "exec -- passes dash-commands through" "$(cat "$PODMAN_LOG")" "bash -lc --version"

# A stopped sandbox is restarted, but a missing one is never built implicitly:
# a typo'd -C path would otherwise spend minutes creating a fresh sandbox only
# to run the command in an empty workspace.
: > "$PODMAN_LOG"
env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    "$SANDBOX" exec -C "$PROJECT_A" true </dev/null >/dev/null 2>&1 ||
    fail "exec on a stopped sandbox failed"
assert_str_contains "exec starts a stopped sandbox" "$(cat "$PODMAN_LOG")" "start $NAME_A1"

assert_failure_contains "exec refuses to build a missing sandbox" "No sandbox exists" \
    env "${STATE_ENV[@]}" "$SANDBOX" exec -C "$PROJECT_A" true

assert_failure_contains "exec missing-sandbox error suggests --create" "--create" \
    env "${STATE_ENV[@]}" "$SANDBOX" exec -C "$PROJECT_A" true

: > "$PODMAN_LOG"
env "${STATE_ENV[@]}" "$SANDBOX" exec --create -C "$PROJECT_A" true </dev/null >/dev/null 2>&1 ||
    fail "exec --create failed"
assert_str_contains "exec --create builds the missing sandbox" "$(cat "$PODMAN_LOG")" "run -d --init"

assert_failure_contains "exec refuses a stale sandbox" "created from an older image" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" \
    STUB_IMAGE_ID="sha256:new" STUB_CONTAINER_IMAGE_ID="sha256:old" \
    "$SANDBOX" exec -C "$PROJECT_A" true

assert_failure_contains "exec refuses a project collision" "already belongs to a different project" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="/some/other/project" \
    "$SANDBOX" exec -C "$PROJECT_A" true

# exec is the scripted fast path: unlike start/shell it does NOT re-seed a
# running sandbox — two extra podman execs per command is real overhead in a
# loop, and config added upstream still lands on the next start/shell.
output="$(env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_RUNNING="$NAME_A1" \
    STUB_LABEL_PROJECT="$PROJECT_A" STUB_LABEL_HOST_AUTH="0" \
    "$SANDBOX" exec -C "$PROJECT_A" true </dev/null 2>&1)" || fail "exec fast-path run failed"
assert_str_not_contains "exec does not re-seed a running sandbox" "$output" "Seeding agent config"

# A stopped stale container flows through start_container, which must refuse
# the same way the running case does — there is no live session to protect.
assert_failure_contains "exec refuses a stopped stale sandbox" "created from an older image" \
    env "${STATE_ENV[@]}" STUB_EXISTING="$NAME_A1" STUB_LABEL_PROJECT="$PROJECT_A" \
    STUB_IMAGE_ID="sha256:new" STUB_CONTAINER_IMAGE_ID="sha256:old" \
    "$SANDBOX" exec -C "$PROJECT_A" true

# --- An unresolvable project path is reported, not silently swallowed ---

# root can cd into a mode-000 directory, so this only proves anything unprivileged.
if [ "$(id -u)" -ne 0 ]; then
    NOEXEC_DIR="$TMP_DIR/no-exec"
    mkdir -p "$NOEXEC_DIR"
    chmod 000 "$NOEXEC_DIR"
    assert_failure_contains "unresolvable project path is reported" "Cannot resolve project path" \
        env "${STATE_ENV[@]}" "$SANDBOX" start "$NOEXEC_DIR"
    chmod 755 "$NOEXEC_DIR"
else
    echo "skip - running as root (path-permission test)"
fi

# --- Remaining environment overrides ---

: > "$PODMAN_LOG"
output="$(env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    SANDBOX_MOUNT_HOST_AUTH=1 "$SANDBOX" start "$PROJECT_A" </dev/null 2>&1)" ||
    fail "SANDBOX_MOUNT_HOST_AUTH start failed"
assert_str_contains "SANDBOX_MOUNT_HOST_AUTH makes host-auth the default" "$(run_line)" \
    "--label sandbox.host-auth=1"
assert_str_contains "host-auth always warns about credential exposure" "$output" \
    "mounts host agent credentials"

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    SANDBOX_CONTAINER_PREFIX=zzz "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 ||
    fail "SANDBOX_CONTAINER_PREFIX start failed"
assert_str_contains "SANDBOX_CONTAINER_PREFIX renames the container" "$(run_line)" "--name zzz-"

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    SANDBOX_IMAGE_NAME=localhost/custom-image "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 ||
    fail "SANDBOX_IMAGE_NAME start failed"
assert_str_contains "SANDBOX_IMAGE_NAME overrides the image" "$(run_line)" "localhost/custom-image"

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    SANDBOX_CONTAINER_USER=coder "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 ||
    fail "SANDBOX_CONTAINER_USER start failed"
assert_str_contains "SANDBOX_CONTAINER_USER moves the state volumes" "$(run_line)" \
    "-claude:/home/coder/.claude"

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    SANDBOX_MEMORY=2g SANDBOX_PIDS_LIMIT=512 \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 ||
    fail "SANDBOX_MEMORY/SANDBOX_PIDS_LIMIT start failed"
RUN_ARGS="$(run_line)"
assert_str_contains "SANDBOX_MEMORY overrides the memory ceiling" "$RUN_ARGS" "--memory 2g"
assert_str_contains "SANDBOX_PIDS_LIMIT overrides the pid ceiling" "$RUN_ARGS" "--pids-limit 512"

: > "$PODMAN_LOG"
env HOME="$FAKE_HOME" PODMAN_LOG="$PODMAN_LOG" PATH="$LIFECYCLE_BIN:$PATH" \
    SANDBOX_MEMORY=0 SANDBOX_PIDS_LIMIT=0 \
    "$SANDBOX" start "$PROJECT_A" </dev/null >/dev/null 2>&1 ||
    fail "zeroed resource limits start failed"
RUN_ARGS="$(run_line)"
assert_str_not_contains "SANDBOX_MEMORY=0 drops the memory ceiling" "$RUN_ARGS" "--memory"
assert_str_not_contains "SANDBOX_PIDS_LIMIT=0 drops the pid ceiling" "$RUN_ARGS" "--pids-limit"
