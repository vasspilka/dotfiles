# Sandbox Alternatives

_Last researched: 2026-05-04_

This document captures open-source and relevant adjacent solutions for the local AI/development sandbox in this directory. The current implementation is a lightweight Podman wrapper that starts a per-project container with mise, browser tooling, and coding-agent CLIs.

## Evaluation criteria

Useful alternatives should ideally provide:

- Local-first operation on macOS/Linux.
- Container or stronger isolation for coding agents and untrusted repos.
- Per-project lifecycle management.
- Persistent but isolated tool/auth/cache state.
- Workspace bind mounts with clear security trade-offs.
- Port forwarding/exposing for local web apps.
- Support for custom images/toolchains.
- Low operational overhead for personal dotfiles.

## Best-fit options

### Dev Containers spec + CLI

- **Links**: https://github.com/devcontainers/spec, https://github.com/devcontainers/cli
- **License**: MIT for CLI; spec/docs are CC-BY-4.0.
- **What it is**: A standard `devcontainer.json` format and reference CLI for building, starting, configuring, and executing commands inside development containers.
- **Relevant capabilities**:
  - `devcontainer build`, `devcontainer up`, `devcontainer exec`.
  - Standard `features`, `mounts`, `containerEnv`, `remoteEnv`, `runArgs`, `forwardPorts`, lifecycle hooks.
  - Reusable across VS Code, Cursor, JetBrains, GitHub Codespaces, and terminal workflows.
  - Can often be used with Podman by passing a Docker-compatible CLI path, e.g. `--docker-path podman`, though compatibility should be tested for our use case.
- **Fit for this repo**: Best foundation if we want to avoid maintaining custom lifecycle/config semantics.
- **Trade-offs**:
  - Adds `devcontainer.json` concepts.
  - `devcontainer stop/down` support has historically lagged behind `up/exec`, so a small wrapper may still be useful.
  - Podman compatibility can be imperfect, especially on macOS.

**Recommended use here**: Keep `sandbox` as a personal convenience CLI, but make it generate or invoke a Dev Containers-compatible configuration where practical.

### Trail of Bits Claude Code devcontainer

- **Link**: https://github.com/trailofbits/claude-code-devcontainer
- **License**: Apache-2.0.
- **What it is**: A sandboxed devcontainer for running Claude Code, designed for security-audit and untrusted-code workflows.
- **Relevant capabilities / patterns**:
  - Per-project containers with isolated volumes.
  - Claude Code setup for terminal workflows.
  - Security guidance around avoiding broad host mounts.
  - Optional readonly mounts for sharing selected host folders.
  - Network-isolation examples.
- **Fit for this repo**: Closest open-source reference for the exact goal of safely running a coding agent in a container.
- **Trade-offs**:
  - Docker/devcontainer-oriented rather than Podman-first.
  - Claude-focused rather than generic Claude/Gemini/Pi.

**Recommended use here**: Borrow hardening patterns: avoid mounting `$HOME`, avoid writable credential mounts, prefer project-scoped volumes, add read-only optional mounts, and document threat model.

### Anthropic Claude Code Dev Container guidance

- **Link**: https://code.claude.com/docs/en/devcontainer
- **License**: Documentation/reference, not a standalone OSS project.
- **What it is**: Official guidance for running Claude Code inside dev containers.
- **Relevant capabilities / patterns**:
  - Claude Code Dev Container Feature: `ghcr.io/anthropics/devcontainer-features/claude-code`.
  - Persistent named volume for `~/.claude` instead of mounting host credentials.
  - Warning that `--dangerously-skip-permissions` does not protect credentials available inside the container.
  - Recommendation to avoid mounting host secrets such as `~/.ssh` or cloud credentials.
  - Optional egress firewall pattern using container capabilities.
  - Non-root user requirement for bypass-permissions mode.
- **Fit for this repo**: Important reference for security decisions, especially because our current implementation mounts agent credentials into a root container.
- **Trade-offs**:
  - Claude-specific.
  - Some patterns assume editor devcontainer workflows.

**Recommended use here**: Align the local sandbox defaults with this guidance: non-root user, named credential volumes, no broad secret mounts by default, and optional network restrictions.

### Microsandbox

- **Link**: https://github.com/superradcompany/microsandbox
- **License**: Apache-2.0.
- **What it is**: Local, rootless, programmable sandboxes for AI agents, backed by lightweight microVMs.
- **Relevant capabilities**:
  - Hardware-level isolation with microVM technology.
  - Local execution with no long-running server/daemon.
  - OCI-compatible images from Docker Hub/GHCR/registries.
  - SDKs for Rust, Python, and TypeScript.
  - CLI (`msb`) for one-command VM launches.
  - Long-running detached sandboxes.
  - Agent Skills and MCP server for Claude Code, Cursor, Codex, Gemini CLI, GitHub Copilot, and other agents.
- **Fit for this repo**: Most interesting if the goal shifts from “developer shell in a Podman container” to “agents can create and control isolated sandboxes themselves”.
- **Trade-offs**:
  - Beta software with expected breaking changes/rough edges.
  - Requirements are Linux with KVM enabled or Apple Silicon macOS.
  - Different operational model than the current Podman wrapper.

**Recommended use here**: Track as a possible future replacement if stronger isolation and MCP/agent-managed sandbox lifecycle become more important than simple Podman/devcontainer compatibility.

### DevPod

- **Link**: https://github.com/loft-sh/devpod
- **License**: MPL-2.0.
- **What it is**: Open-source, client-only Codespaces-like tool for creating reproducible dev environments from `devcontainer.json` on local Docker, SSH hosts, Kubernetes, or cloud VMs.
- **Relevant capabilities**:
  - Devcontainer-based workspaces.
  - Local and remote backends.
  - IDE integration and SSH access.
  - Prebuilds, inactivity shutdown, credential sync.
- **Fit for this repo**: Good if we want portability beyond a single local Podman machine.
- **Trade-offs**:
  - More product/tooling than a small shell alias.
  - May be heavier than needed for personal dotfiles.

**Recommended use here**: Consider only if local Podman is not enough or remote workspaces become important.

## Agent sandbox platforms

### OpenHands

- **Link**: https://github.com/OpenHands/OpenHands
- **License**: Mostly MIT, with separate enterprise licensing for enterprise-only areas.
- **What it is**: An AI-driven development platform with a Docker sandbox runtime for agents.
- **Relevant capabilities**:
  - Docker sandbox provider.
  - Custom sandbox images.
  - Local repo mounting via CLI options/environment variables.
  - Full agent application stack.
- **Fit for this repo**: Useful design reference for agent/runtime separation, but much larger than a personal sandbox wrapper.
- **Trade-offs**:
  - Solves a broader problem than “open a shell with Claude/Gemini in a sandbox”.
  - Adopting it would replace the workflow rather than refine it.

### OpenSandbox by Alibaba

- **Link**: https://github.com/alibaba/OpenSandbox
- **License**: Apache-2.0.
- **What it is**: General-purpose sandbox platform for AI applications with SDKs, CLI, MCP support, Docker/Kubernetes runtimes, ingress/egress controls, and support for stronger isolation runtimes.
- **Relevant capabilities**:
  - Sandbox lifecycle APIs.
  - Command execution and filesystem operations.
  - CLI: create sandboxes, run commands, move files, diagnostics, egress policy.
  - MCP server for clients like Claude Code/Cursor.
  - Docker/Kubernetes runtimes.
  - Mentions gVisor, Kata Containers, and Firecracker microVM support for stronger isolation.
- **Fit for this repo**: Strong option if we want a real sandbox service/API rather than a local shell wrapper.
- **Trade-offs**:
  - Requires running a sandbox server.
  - More infrastructure than needed for simple personal use.

### E2B

- **Links**: https://github.com/e2b-dev/E2B, https://github.com/e2b-dev/infra
- **License**: Apache-2.0.
- **What it is**: Open-source cloud sandbox infrastructure for AI-generated code execution, with Python/JavaScript SDKs and self-hosting infrastructure.
- **Relevant capabilities**:
  - Secure isolated cloud sandboxes.
  - Command/code execution APIs.
  - Templates/environments.
  - Self-hosting through Terraform, primarily for AWS/GCP.
- **Fit for this repo**: Good reference for API-driven cloud sandboxes, but likely overkill for local dotfiles.
- **Trade-offs**:
  - Cloud/API-centric.
  - Self-hosting is infrastructure-heavy and not aimed at a single local machine.

### Daytona

- **Link**: https://github.com/daytonaio/daytona
- **License**: AGPL-3.0.
- **What it is**: Secure and elastic infrastructure for AI-generated code execution and agent workflows.
- **Relevant capabilities**:
  - Sandboxes with filesystem/process/code execution APIs.
  - Snapshots/persistence.
  - CLI, API, and SDKs.
  - Open-source deployment via Docker Compose.
- **Fit for this repo**: Feature-rich platform if we need persistent agent workspaces and APIs.
- **Trade-offs**:
  - AGPL license may be undesirable for reuse in dotfiles or derivative tooling.
  - Much heavier than a local Podman wrapper.

## Development environment platforms

### Coder

- **Link**: https://github.com/coder/coder
- **License**: AGPL-3.0.
- **What it is**: Self-hosted cloud development environments defined with Terraform and backed by Docker/Kubernetes/VMs.
- **Relevant capabilities**:
  - Workspace lifecycle management.
  - Docker/Kubernetes/VM templates.
  - Secure tunnels and idle shutdown.
  - Team/enterprise workflows.
- **Fit for this repo**: Useful if this evolves into shared/team dev environments; too heavy for personal local sandboxing.
- **Trade-offs**:
  - Server and Terraform model.
  - AGPL license.

### Dagger

- **Link**: https://github.com/dagger/dagger
- **License**: Apache-2.0.
- **What it is**: Programmable container-based automation engine for builds/tests/CI workflows.
- **Relevant capabilities**:
  - Local-first container runtime execution.
  - Typed SDKs including Elixir.
  - Strong caching and reproducibility.
  - Useful for running tasks in clean containers.
- **Fit for this repo**: Better for repeatable build/test automation than interactive coding-agent shells.
- **Trade-offs**:
  - Not primarily a long-lived dev shell manager.

## Isolation/runtime building blocks

These are not full sandbox CLIs, but are useful if we want stronger isolation than ordinary containers.

### Podman

- **Link**: https://github.com/containers/podman
- **License**: Apache-2.0.
- **Current use**: This sandbox already uses Podman.
- **Pros**: Daemonless, rootless-friendly, Docker-compatible CLI surface, good Linux support.
- **Cons**: On macOS it runs through a VM; volume/performance/network behavior differs from Linux.

### gVisor

- **Link**: https://github.com/google/gvisor
- **License**: Apache-2.0.
- **What it provides**: User-space kernel / sandboxed container runtime.
- **Use if**: We need stronger isolation for Linux-hosted containers.

### Kata Containers

- **Link**: https://github.com/kata-containers/kata-containers
- **License**: Apache-2.0.
- **What it provides**: Lightweight VMs that feel like containers.
- **Use if**: We need VM-level isolation while preserving container workflows.

### Firecracker

- **Link**: https://github.com/firecracker-microvm/firecracker
- **License**: Apache-2.0.
- **What it provides**: Secure, fast microVMs.
- **Use if**: We build or adopt a sandbox service that launches microVMs.

### bubblewrap / nsjail / Firejail

- **Links**:
  - https://github.com/containers/bubblewrap
  - https://github.com/google/nsjail
  - https://github.com/netblue30/firejail
- **What they provide**: Linux namespace/seccomp/cgroup-based process isolation.
- **Fit for this repo**: Lower-level Linux-only alternatives. Less attractive for macOS-first dotfiles.

## Non-open-source or adjacent references

### Docker Sandboxes / Coding Sandbox

- **Links**: https://docs.docker.com/ai/sandboxes/, https://coding-sandbox.dev/
- **What they are**: Docker-oriented products/docs for sandboxing coding agents.
- **Fit for this repo**: Useful UX/product references, especially for one-click creation, logs, telemetry, snapshots, and tunnels.
- **Trade-offs**: Not a clear open-source replacement for this local Podman script.

## Recommendation

For this dotfiles repo, the best direction is:

1. Keep a small `sandbox` CLI for personal ergonomics.
2. Fix the immediate correctness/security issues in the current shell script.
3. Move toward Dev Containers-compatible configuration instead of inventing a custom configuration format.
4. Use Trail of Bits and Anthropic devcontainer guidance as the hardening baseline.
5. Treat OpenSandbox/E2B/Daytona/Coder as heavier platforms to revisit only if this becomes a shared service or needs programmatic sandbox APIs.

## Design implications for the current sandbox

The research suggested the following default changes. All are now implemented:

- [x] Do **not** mount host agent credential directories by default.
- [x] Prefer per-project named volumes for agent state, e.g. Claude/Gemini/Pi config volumes.
- [x] Add explicit opt-in flags for mounting host credentials, with warnings.
- [x] Run as a non-root user inside the container.
- [x] Add an optional network-egress restriction mode — `--network MODE` / `--no-network`, plus `SANDBOX_NETWORK`.
- [x] Validate user inputs before passing them to Podman/socat.
- [x] Add a `recreate` or image-staleness check so rebuilt images actually affect existing sandboxes.
- [x] Consider `devcontainer.json` support for ports, mounts, environment, and lifecycle hooks — partial: `forwardPorts` and confirmed `mounts` only.
- [x] Keep host bind mounts to the minimum the tool actually needs — the dotfiles repo is no longer mounted; shared agent config is streamed in over `podman exec` instead, leaving only the project and two read-only git config files.
- [x] Provide a non-interactive entry point so the sandbox is usable from scripts and from agents on the host — `sandbox exec`.

### Still open

- **No image-level verification.** `test.sh` stubs Podman and never builds the image, so `Dockerfile` regressions (a missing apt package, a base-image uid collision) surface only on a real `sandbox build`. A slow opt-in check that builds the image and runs `mise install` against `.tool-versions` would close the gap that produced the missing Erlang build dependencies.

- **Allowlist-based egress filtering.** `--network none` is all-or-nothing. Letting an agent reach `registry.npmjs.org` and `api.anthropic.com` but nothing else needs a filtering proxy or per-container firewall rules; both are more machinery than this wrapper should carry today. Revisit alongside the Dev Containers migration.
- **Lifecycle hooks** (`postCreateCommand` and friends) from `devcontainer.json`.
- **Per-project image variants**, currently one shared image for every sandbox.
