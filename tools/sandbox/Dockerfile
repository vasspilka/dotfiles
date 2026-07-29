ARG PLAYWRIGHT_VERSION=1.62.0
ARG SANDBOX_USER=developer
ARG SANDBOX_UID=1000
ARG SANDBOX_GID=1000

# Use a slim Ubuntu base with Playwright browser dependencies.
FROM mcr.microsoft.com/playwright:v${PLAYWRIGHT_VERSION}-jammy

ARG PLAYWRIGHT_VERSION
ARG SANDBOX_USER
ARG SANDBOX_UID
ARG SANDBOX_GID

# Install system dependencies.
#
# The Erlang group is not optional: mise builds Erlang from source via kerl, and
# OTP's configure aborts with "No curses library functions found" without
# libncurses-dev, and cannot bootstrap without autoconf/m4. Since .tool-versions
# pins Erlang and Elixir is this repo's primary stack, omitting these turns the
# very first `sandbox` in a Phoenix project into a failed `mise install`.
# inotify-tools is what Phoenix live reload uses for file watching on Linux.
# git-lfs is required, not optional: the host ~/.gitconfig mounted into the
# sandbox marks the LFS filter as required=true, so git operations in LFS repos
# hard-fail without the binary. No `git lfs install` is needed — the filter
# config it would write already comes in via that mount.
RUN apt-get update && apt-get install -y \
    curl gpg git git-lfs build-essential \
    ca-certificates \
    netcat-openbsd \
    unzip \
    autoconf m4 pkg-config \
    libssl-dev zlib1g-dev libncurses-dev \
    inotify-tools \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI — the host ~/.gitconfig mounted into the sandbox delegates
# credentials to `gh auth git-credential`, so gh must exist in the image.
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

# Install mise to a global location (installer selects the correct Linux architecture).
RUN curl -fsSL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh && \
    /usr/local/bin/mise --version

# Create/normalize a non-root user for interactive agent work. The Playwright
# base image already ships a uid/gid 1000 user (`pwuser`), so rename it when
# present instead of failing on duplicate uid/gid.
RUN set -eux; \
    existing_group="$(getent group "${SANDBOX_GID}" | cut -d: -f1 || true)"; \
    if [ -n "$existing_group" ] && [ "$existing_group" != "${SANDBOX_USER}" ]; then \
      groupmod -n "${SANDBOX_USER}" "$existing_group"; \
    elif [ -z "$existing_group" ]; then \
      groupadd --gid "${SANDBOX_GID}" "${SANDBOX_USER}"; \
    fi; \
    existing_user="$(getent passwd "${SANDBOX_UID}" | cut -d: -f1 || true)"; \
    if [ -n "$existing_user" ] && [ "$existing_user" != "${SANDBOX_USER}" ]; then \
      usermod -l "${SANDBOX_USER}" -d "/home/${SANDBOX_USER}" -m "$existing_user"; \
    elif [ -z "$existing_user" ]; then \
      useradd --uid "${SANDBOX_UID}" --gid "${SANDBOX_GID}" --create-home --shell /bin/bash "${SANDBOX_USER}"; \
    fi; \
    usermod --gid "${SANDBOX_GID}" --shell /bin/bash "${SANDBOX_USER}"; \
    mkdir -p "/workspace/_build" "/workspace/deps" "/home/${SANDBOX_USER}/.local/share/mise"; \
    chown -R "${SANDBOX_USER}:${SANDBOX_USER}" "/workspace" "/home/${SANDBOX_USER}"

# Configure environment.
ENV HOME="/home/${SANDBOX_USER}"
ENV MISE_DATA_DIR="/home/${SANDBOX_USER}/.local/share/mise"
ENV NODE_PATH=/usr/lib/node_modules:/usr/local/lib/node_modules
ENV PATH="/usr/local/bin:/home/${SANDBOX_USER}/.local/share/mise/bin:/home/${SANDBOX_USER}/.local/share/mise/shims:$PATH"

# Playwright npm packages must match the browsers baked into the base image, so
# they stay pinned to PLAYWRIGHT_VERSION. They sit in their own layer, ahead of
# the agent CLIs, so `--update-agents` does not re-download Chromium below.
RUN npm install -g \
    "playwright@${PLAYWRIGHT_VERSION}" \
    "@playwright/test@${PLAYWRIGHT_VERSION}"

# Pre-install the Chromium browser expected by the pinned Playwright package.
RUN playwright install --with-deps chromium

# The agent CLIs are unpinned, and Podman caches this layer: a plain
# `sandbox build` will NOT pick up new releases. `sandbox build --update-agents`
# busts AGENT_CLI_EPOCH, invalidating only this layer — the pinned Playwright
# and browser layers above stay cached. `sandbox build --fresh` rebuilds all.
#
# @playwright/mcp provides the `playwright-mcp` binary. sandbox.sh rewrites the
# seeded MCP config to call that binary directly, because `npx -y @playwright/mcp`
# would NOT resolve this install: npm exec looks for a global bin named exactly
# "@playwright/mcp", finds none (the bin is `playwright-mcp`), and falls through
# to a registry fetch. Calling the binary means no download at launch, so it
# works under `sandbox --network none` and its version is fixed at image build
# time rather than changing under you. It is unpinned like the agent CLIs, so it
# lives in this layer rather than the pinned one.
ARG AGENT_CLI_EPOCH=0
RUN echo "agent-cli-epoch=${AGENT_CLI_EPOCH}" > /dev/null && npm install -g \
    @playwright/mcp \
    @anthropic-ai/claude-code \
    @google/gemini-cli

# Note: the Pi CLI is deliberately not installed here — it has no pinned public
# package. sandbox.sh still provisions an isolated /home/developer/.pi volume so
# that installing Pi in-container keeps its state per-project.

# Ensure mise is active for interactive Bash shells.
RUN echo 'export PATH="/usr/local/bin:${HOME}/.local/share/mise/bin:${HOME}/.local/share/mise/shims:$PATH"' >> /etc/bash.bashrc && \
    echo 'eval "$(/usr/local/bin/mise activate bash)"' >> /etc/bash.bashrc && \
    echo 'export PATH="/usr/local/bin:${HOME}/.local/share/mise/bin:${HOME}/.local/share/mise/shims:$PATH"' >> "/home/${SANDBOX_USER}/.bashrc" && \
    echo 'eval "$(/usr/local/bin/mise activate bash)"' >> "/home/${SANDBOX_USER}/.bashrc" && \
    mkdir -p "/home/${SANDBOX_USER}/.cache/mise" && \
    chown -R "${SANDBOX_USER}:${SANDBOX_USER}" "/home/${SANDBOX_USER}"

USER ${SANDBOX_USER}
WORKDIR /workspace

CMD ["sleep", "infinity"]
