# AI CLI sandbox on Ubuntu 24.04 LTS.
#
# Ubuntu was chosen because it is the distro all of these tools
# support out of the box: Kiro ships an Ubuntu .deb, NodeSource
# covers the npm-installed agents, and the goose and aider install
# scripts target Debian/Ubuntu first.
#
# Agents installed (command names in parentheses):
#   Claude Code (claude), Kiro CLI (kiro-cli), opencode, openclaw,
#   goose, pi, aider
#
# Build with the container user named after the invoking user so
# absolute paths (and the session state that tools key on them)
# match between host and container:
#
#   podman build --build-arg USERNAME="$(id -un)" \
#       --build-arg USERSHELL="${SHELL}" \
#       -t aisandbox -f Containerfile .
#
# Start with the start-aisandbox script.
#
# Note: the Kiro .deb is amd64-only; on arm64 replace that step
# with the zip from
# https://desktop-release.q.us-east-1.amazonaws.com/latest/kirocli-aarch64-linux.zip

FROM docker.io/library/ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8

# Everything installed from Ubuntu's repositories, in one layer:
#
# - common development tools, plus runtime libraries the agents
#   need (libdbus-1-3/libxcb1 for goose's keyring, bzip2 for its
#   release tarball), and zsh;
# - linters: C/C++ (cppcheck, clang-tidy, clang-format, splint),
#   Python (pylint, flake8, mypy, black), shell (shellcheck,
#   shfmt), YAML (yamllint), Lua (lua-check), Perl
#   (libperl-critic-perl), XML (libxml2-utils), HTML (tidy), and
#   spelling (codespell);
# - documentation toolchain: python3-docutils (rst2html and the
#   other rst2* tools), sphinx, and everything the PostgreSQL
#   documentation build requires (docbook-xml, docbook-xsl,
#   xsltproc, fop, libxml2-utils);
# - build systems: meson and ninja, plus the Go toolchain (gofmt
#   and go vet come with it);
# - observability: sysstat (sar, pidstat, iostat, mpstat),
#   collectd (no init system here, so run it in the foreground:
#   "collectd -f -C <config>"), and perf;
# - shunit2 shell-script unit-test framework.
#
# Two symlinks at the end: Ubuntu names the fd binary fdfind, and
# Ubuntu's /usr/bin/perf wrapper dispatches on the running kernel
# version, which inside a container is the host's kernel and
# never matches an Ubuntu tools package, so link the real binary.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        black \
        build-essential \
        bzip2 \
        ca-certificates \
        clang-format \
        clang-tidy \
        cmake \
        codespell \
        collectd \
        collectd-utils \
        cppcheck \
        cscope \
        curl \
        docbook-xml \
        docbook-xsl \
        fd-find \
        flake8 \
        fop \
        fzf \
        gdb \
        git \
        gnupg \
        gnuplot \
        golang-go \
        jq \
        less \
        libdbus-1-3 \
        libperl-critic-perl \
        libxcb1 \
        libxml2-utils \
        linux-tools-generic \
        lua-check \
        man-db \
        meson \
        mypy \
        neovim \
        ninja-build \
        openssh-client \
        patch \
        pkg-config \
        pylint \
        python3 \
        python3-docutils \
        python3-pip \
        python3-sphinx \
        python3-venv \
        quilt \
        ripgrep \
        shellcheck \
        shfmt \
        shunit2 \
        splint \
        strace \
        sysstat \
        tidy \
        tmux \
        tree \
        universal-ctags \
        unzip \
        wget \
        xsltproc \
        xz-utils \
        yamllint \
        zip \
        zsh \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "$(command -v fdfind)" /usr/local/bin/fd \
    && ln -s "$(find /usr/lib/linux-tools* -name perf | head -1)" \
        /usr/local/bin/perf

# Node.js 24 (openclaw requires >= 22.22.3; 24.x covers all the
# npm-installed agents).
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y --no-install-recommends nodejs

# Kiro CLI from the official Ubuntu package (installs system-wide,
# unlike the per-user https://cli.kiro.dev/install script).
RUN curl -fsSL -o /tmp/kiro-cli.deb \
        https://desktop-release.q.us-east-1.amazonaws.com/latest/kiro-cli.deb \
    && apt-get install -y --no-install-recommends /tmp/kiro-cli.deb \
    && rm -f /tmp/kiro-cli.deb \
    && rm -rf /var/lib/apt/lists/*

# npm-distributed agents: Claude Code, opencode, openclaw, and
# Mario Zechner's pi.
RUN npm install -g \
        @anthropic-ai/claude-code \
        @mariozechner/pi-coding-agent \
        opencode-ai \
        openclaw

# goose (Block). CONFIGURE=false skips the interactive setup that
# the install script otherwise runs.
RUN curl -fsSL \
        https://github.com/block/goose/releases/download/stable/download_cli.sh \
    | GOOSE_BIN_DIR=/usr/local/bin CONFIGURE=false bash

# aider, installed the way its own install script does (via uv)
# but into system-wide locations so any user can run it.
RUN curl -LsSf https://astral.sh/uv/install.sh \
    | env UV_INSTALL_DIR=/usr/local/bin sh \
    && env UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin \
        uv tool install --python 3.12 aider-chat \
    && chmod -R a+rX /opt/uv-tools

# Linters distributed via npm: JavaScript, CSS, HTML, JSON, and
# Markdown.
RUN npm install -g \
        eslint \
        htmlhint \
        jsonlint \
        markdownlint-cli \
        stylelint

# Python-based linters not packaged by Ubuntu, installed like
# aider (isolated uv tools with system-wide commands):
# reStructuredText (doc8, rst-lint), SQL (sqlfluff), C++ style
# (cpplint), and prose (proselint).
RUN env UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin \
        sh -c 'for t in cpplint doc8 proselint \
            restructuredtext-lint sqlfluff; do \
                uv tool install --python 3.12 "${t}" || exit 1; \
            done' \
    && chmod -R a+rX /opt/uv-tools

# hadolint (Containerfile/Dockerfile linter); amd64 binary, like
# the Kiro CLI step above.
RUN curl -fsSL -o /usr/local/bin/hadolint \
        https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 \
    && chmod +x /usr/local/bin/hadolint

# golangci-lint, the standard Go meta-linter (bundles staticcheck
# and friends); amd64 binary, like the Kiro CLI step above.
# Downloaded directly instead of via the project's install.sh:
# that script's checksum lookup greps the checksums file by
# filename, which now also matches the release's
# "....tar.gz.sbom.json" asset, so it compares the tarball
# against the wrong hash and always fails.  The exact-match
# verification below checks the same published checksum
# correctly.  Bump the pinned version here to update.
RUN v="2.12.2" \
    && base="golangci-lint-${v}-linux-amd64" \
    && url="https://github.com/golangci/golangci-lint/releases/download/v${v}" \
    && cd /tmp \
    && curl -fsSL -O "${url}/${base}.tar.gz" \
    && curl -fsSL "${url}/golangci-lint-${v}-checksums.txt" \
        | awk -v f="${base}.tar.gz" '$2 == f' \
        | sha256sum -c - \
    && tar -xzf "${base}.tar.gz" \
    && mv "${base}/golangci-lint" /usr/local/bin/ \
    && rm -rf "${base}" "${base}.tar.gz"

# Rust via rustup, installed system-wide and read-only.  The
# default profile includes clippy (linter) and rustfmt.  Only
# RUSTUP_HOME is exported: CARGO_HOME stays at its ~/.cargo
# default so per-user cargo builds can write their registry.
RUN curl -fsSL https://sh.rustup.rs \
    | env RUSTUP_HOME=/opt/rust CARGO_HOME=/opt/rust \
        sh -s -- -y --no-modify-path --profile default \
    && chmod -R a+rX /opt/rust
ENV RUSTUP_HOME=/opt/rust \
    PATH=/opt/rust/bin:${PATH}

# Rename the stock "ubuntu" user (uid 1000) after the invoking
# host user.  Claude Code and other agents key per-project state
# on absolute paths, so /home/<user> must match the host for
# sessions started on one side to resume on the other.
ARG USERNAME=ubuntu
RUN if [ "${USERNAME}" != "ubuntu" ]; then \
        usermod -l "${USERNAME}" -d "/home/${USERNAME}" -m \
            ubuntu \
        && groupmod -n "${USERNAME}" ubuntu; \
    fi

# Give the container user the same login shell as on the host so
# ${SHELL} and anything that spawns it behave alike.
ARG USERSHELL=/bin/bash
RUN usermod -s "${USERSHELL}" "${USERNAME}"

# Updating inside a container makes no sense; pin what was built.
ENV DISABLE_AUTOUPDATER=1

# Run unprivileged; several agents complain when run as root.
USER ${USERNAME}
WORKDIR /home/${USERNAME}/work

CMD ["/bin/bash"]
