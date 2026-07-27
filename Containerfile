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
# - document and image handling: pandoc, poppler-utils
#   (pdftotext and friends, so agents can read PDFs), graphviz,
#   and imagemagick;
# - benchmarking and code statistics: hyperfine and cloc, plus
#   entr to watch files and rerun commands;
# - everyday utilities the agents expect to find: file, git-lfs,
#   moreutils (sponge), rsync, sqlite3, dos2unix, and zstd;
# - shunit2 shell-script unit-test framework.
#
# At the end, "git lfs install --system" registers the LFS
# filters so clones fetch LFS content, and two symlinks: Ubuntu
# names the fd binary fdfind, and Ubuntu's /usr/bin/perf wrapper
# dispatches on the running kernel version, which inside a
# container is the host's kernel and never matches an Ubuntu
# tools package, so link the real binary.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        bison \
        black \
        build-essential \
        bzip2 \
        ca-certificates \
        clang-format \
        clang-tidy \
        cloc \
        cmake \
        codespell \
        collectd \
        collectd-utils \
        cppcheck \
        cscope \
        curl \
        docbook-xml \
        docbook-xsl \
        dos2unix \
        entr \
        fd-find \
        file \
        flake8 \
        flex \
        fop \
        fzf \
        gdb \
        git \
        git-lfs \
        gnupg \
        gnuplot \
        golang-go \
        graphviz \
        hyperfine \
        imagemagick \
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
        moreutils \
        mypy \
        neovim \
        ninja-build \
        openssh-client \
        pandoc \
        patch \
        pkg-config \
        poppler-utils \
        pylint \
        python3 \
        python3-docutils \
        python3-pip \
        python3-sphinx \
        python3-venv \
        quilt \
        ripgrep \
        rsync \
        shellcheck \
        shfmt \
        shunit2 \
        splint \
        sqlite3 \
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
        zstd \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install --system \
    && ln -s "$(command -v fdfind)" /usr/local/bin/fd \
    && ln -s "$(find /usr/lib/linux-tools* -name perf | head -1)" \
        /usr/local/bin/perf

# Node.js 24 (openclaw requires >= 22.22.3; 24.x covers all the
# npm-installed agents), from NodeSource's repository.  The
# repository is set up manually instead of running their
# setup_24.x script: that script drives the plain "apt" command,
# which warns that it has no stable CLI interface; the steps
# here stick to apt-get, the stable scripting interface.
RUN key=/etc/apt/keyrings/nodesource.gpg \
    && mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL \
        https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
    | gpg --dearmor -o "${key}" \
    && chmod a+r "${key}" \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=${key}]" \
        "https://deb.nodesource.com/node_24.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Kiro CLI from the official Ubuntu package (installs system-wide,
# unlike the per-user https://cli.kiro.dev/install script).
RUN curl -fsSL -o /tmp/kiro-cli.deb \
        https://desktop-release.q.us-east-1.amazonaws.com/latest/kiro-cli.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/kiro-cli.deb \
    && rm -f /tmp/kiro-cli.deb \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI (gh) from GitHub's own apt repository: Ubuntu 24.04
# freezes gh at 2.45.0, while the upstream repository tracks
# current releases.
RUN key=/etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && mkdir -p -m 755 /etc/apt/keyrings \
    && curl -fsSL -o "${key}" \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && chmod a+r "${key}" \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=${key}]" \
        "https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# PostgreSQL development packages (libpq and server headers, for
# building client programs and extensions) from the PGDG apt
# repository: Ubuntu 24.04 freezes PostgreSQL at 16, while PGDG
# tracks current releases.  postgresql-common ships the official
# repository setup script, which writes pgdg.sources using its
# bundled signing key and runs apt-get update itself; -y skips
# its confirmation prompt, and it sticks to apt-get throughout.
# postgresql-server-dev-all covers every major version PGDG
# still publishes (currently 10 through 18), so no version is
# pinned here and new majors arrive with a rebuild.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-common \
    && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y \
    && apt-get install -y --no-install-recommends \
        libpq-dev \
        postgresql-server-dev-all \
    && rm -rf /var/lib/apt/lists/*

# npm-distributed agents: Claude Code, opencode, openclaw, and
# Mario Zechner's pi (now published under the @earendil-works
# scope; the old @mariozechner packages are deprecated).
#
# --allow-scripts approves the install scripts these packages
# and their dependencies run: npm 11 only warns about scripts
# not covered by allowScripts, but npm 12 will refuse to run
# them, and "npm approve-scripts" cannot cover global installs.
# The flag is a single argument and cannot be wrapped.
RUN npm install -g \
        --allow-scripts=@anthropic-ai/claude-code,@google/genai,opencode-ai,openclaw,protobufjs,tree-sitter-bash \
        @anthropic-ai/claude-code \
        @earendil-works/pi-coding-agent \
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

# Linters and formatters distributed via npm: JavaScript, CSS,
# HTML, JSON, and Markdown linters, prettier, and the TypeScript
# compiler (tsc).  JSON linting uses the maintained
# @prantlf/jsonlint fork (same jsonlint command): the original
# jsonlint was last published in 2018 and pulls in the abandoned
# nomnom package.
RUN npm install -g \
        @prantlf/jsonlint \
        eslint \
        htmlhint \
        markdownlint-cli \
        prettier \
        stylelint \
        typescript

# Python-based tools either not packaged by Ubuntu or much newer
# upstream, installed like aider (isolated uv tools with
# system-wide commands): reStructuredText (doc8, rst-lint), SQL
# (sqlfluff), C++ style (cpplint), prose (proselint), ruff (the
# Python linter/formatter most agents now default to), and
# pre-commit (many repositories gate on "pre-commit run").
RUN env UV_TOOL_DIR=/opt/uv-tools UV_TOOL_BIN_DIR=/usr/local/bin \
        sh -c 'for t in cpplint doc8 pre-commit proselint \
            restructuredtext-lint ruff sqlfluff; do \
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

# actionlint (GitHub Actions workflow linter); amd64 binary,
# pinned because the release asset name embeds the version.
# Bump the pinned version here to update.
RUN v="1.7.12" \
    && f="actionlint_${v}_linux_amd64.tar.gz" \
    && cd /tmp \
    && curl -fsSL -O \
        "https://github.com/rhysd/actionlint/releases/download/v${v}/${f}" \
    && tar -xzf "${f}" actionlint \
    && mv actionlint /usr/local/bin/ \
    && rm -f "${f}"

# gitleaks (secret scanner, to keep credentials out of commits);
# amd64 binary, pinned like actionlint above.
RUN v="8.30.1" \
    && f="gitleaks_${v}_linux_x64.tar.gz" \
    && cd /tmp \
    && curl -fsSL -O \
        "https://github.com/gitleaks/gitleaks/releases/download/v${v}/${f}" \
    && tar -xzf "${f}" gitleaks \
    && mv gitleaks /usr/local/bin/ \
    && rm -f "${f}"

# mikefarah's yq (Go YAML processor).  Ubuntu's "yq" package is
# the unrelated Python jq wrapper, so install the yq that most
# documentation assumes; amd64 binary, like the hadolint step
# above.
RUN curl -fsSL -o /usr/local/bin/yq \
        https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/local/bin/yq

# ast-grep (structural code search and rewriting).  Not
# installed from its @ast-grep/cli npm package: that package
# also links an "sg" alias, which collides with /usr/bin/sg
# (setgroups, from the shadow suite) under npm's /usr prefix.
# Extract only the ast-grep binary from the release zip; amd64,
# like the hadolint step above.
RUN cd /tmp \
    && curl -fsSL -O \
        https://github.com/ast-grep/ast-grep/releases/latest/download/app-x86_64-unknown-linux-gnu.zip \
    && unzip -o app-x86_64-unknown-linux-gnu.zip ast-grep \
        -d /usr/local/bin \
    && chmod +x /usr/local/bin/ast-grep \
    && rm -f app-x86_64-unknown-linux-gnu.zip

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
