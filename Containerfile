# AI CLI sandbox on Ubuntu 24.04 LTS.
#
# Ubuntu was chosen because it is the distro all of these tools
# support out of the box: Kiro ships an Ubuntu .deb, and the
# goose and aider install scripts target Debian/Ubuntu first.
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
# - database client development files: libmysqlclient-dev
#   (MySQL C API headers and mysql_config, for building client
#   programs; PostgreSQL's and Oracle's equivalents come from
#   PGDG and Oracle Instant Client in later layers);
# - libev-dev: libev event-loop library headers, for building
#   programs that use it;
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
        libev-dev \
        libmysqlclient-dev \
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
# npm-installed agents), from the official nodejs.org binary
# tarball, unpacked into /usr/local; it ships node, npm, npx,
# and corepack.  NodeSource's apt repository, used previously,
# sits behind a Cloudflare challenge that answers plain HTTP
# clients with 403 (nodesource/distributions issue #1844), which
# broke builds.  The tarball name embeds the version, so resolve
# it from the SHASUMS256.txt in the latest-v24.x directory and
# verify the download against that same file, like the
# golangci-lint step below.
RUN case "$(uname -m)" in \
        x86_64) arch=x64 ;; \
        aarch64) arch=arm64 ;; \
        *) echo "unsupported architecture: $(uname -m)"; exit 1 ;; \
    esac \
    && cd /tmp \
    && curl -fsSL -O \
        https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt \
    && f=$(awk -v a="${arch}" \
        '$2 ~ "^node-v.*-linux-" a "\\.tar\\.xz$" { print $2 }' \
        SHASUMS256.txt) \
    && curl -fsSL -O "https://nodejs.org/dist/latest-v24.x/${f}" \
    && awk -v f="${f}" '$2 == f' SHASUMS256.txt | sha256sum -c - \
    && tar -xJf "${f}" -C /usr/local --strip-components=1 \
    && rm -f "${f}" SHASUMS256.txt /usr/local/CHANGELOG.md \
        /usr/local/LICENSE /usr/local/README.md

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
        postgresql-18 \
    && rm -rf /var/lib/apt/lists/*

# Oracle Instant Client, Basic Light and SDK packages: OCI
# client libraries and headers, completing the database client
# development files from the first layer.  Downloaded from
# Oracle's permanent latest-version links under the Oracle Free
# Distribution, Hosting, and Use Terms and Conditions (the
# *_LICENSE files land in the install directory); amd64 zips,
# like the Kiro CLI step above (Oracle publishes arm64 zips
# only under version-numbered URLs).  Basic Light carries
# English-only error messages and Unicode character sets; swap
# "basiclite" for "basic" if full NLS support is ever needed.
# The zips unpack into a version-named directory
# (instantclient_23_26 today); the unversioned
# /opt/oracle/instantclient symlink gives compiler flags a
# stable path (headers in sdk/include), and the ld.so.conf.d
# entry makes the libraries visible system-wide.  Ubuntu
# 24.04's 64-bit time_t transition renamed libaio's soname to
# libaio.so.1t64, while libclntsh needs libaio.so.1, hence the
# compatibility symlink.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libaio1t64 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s libaio.so.1t64 \
        /usr/lib/x86_64-linux-gnu/libaio.so.1 \
    && u="https://download.oracle.com/otn_software/linux/instantclient" \
    && mkdir -p /opt/oracle \
    && cd /tmp \
    && for f in instantclient-basiclite-linuxx64.zip \
            instantclient-sdk-linuxx64.zip; do \
        curl -fsSL -O "${u}/${f}" \
        && unzip -oq "${f}" -d /opt/oracle \
        && rm -f "${f}" \
        || exit 1; \
    done \
    && rm -rf /opt/oracle/META-INF \
    && ln -s /opt/oracle/instantclient_* /opt/oracle/instantclient \
    && echo /opt/oracle/instantclient \
        > /etc/ld.so.conf.d/oracle-instantclient.conf \
    && ldconfig

# MySQL server from Ubuntu's repositories: unlike PostgreSQL,
# Ubuntu keeps MySQL patched (8.0.x), so no third-party
# repository is needed.  A separate layer rather than an
# addition to the first one so the toolchain layer's build
# cache survives.  As with collectd, there is no init system
# here, and the package's /var/lib/mysql is not writable by the
# container user, so initialize a data directory in ${HOME} and
# run the server in the foreground:
#   mysqld --initialize-insecure --datadir="${HOME}/mysql"
#   mysqld --datadir="${HOME}/mysql" \
#       --socket="${HOME}/mysql/mysql.sock"
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        mysql-server-8.0 \
    && rm -rf /var/lib/apt/lists/*

# unixODBC, completing the database client development files
# from the earlier layers: unixodbc-dev carries the ODBC API
# headers (sql.h and friends), libraries, and pkg-config files
# for building ODBC client programs, while unixodbc (isql,
# iusql) and odbcinst supply the command-line tools for testing
# connections and registering drivers.  A separate layer, like
# the MySQL one above, so the earlier layers' build caches
# survive.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        odbcinst \
        unixodbc \
        unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

# R from CRAN's apt repository, set up like the GitHub CLI step
# above: Ubuntu 24.04 freezes R at 4.3.3, while CRAN tracks
# current releases (and publishes both amd64 and arm64
# packages).  r-base-dev brings the headers and toolchain that
# install.packages() needs to build packages from source.
RUN key=/etc/apt/keyrings/cran-archive-keyring.asc \
    && curl -fsSL -o "${key}" \
        https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
    && chmod a+r "${key}" \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=${key}]" \
        "https://cloud.r-project.org/bin/linux/ubuntu noble-cran40/" \
        > /etc/apt/sources.list.d/cran.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        r-base \
        r-base-dev \
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
# also links an "sg" alias, which would shadow /usr/bin/sg
# (setgroups, from the shadow suite) from npm's /usr/local
# prefix.
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

# Julia from the official julialang.org binary tarball, which
# unpacks into a version-named directory under /opt; the
# symlink puts the julia command on the PATH.  Verified against
# the release's published checksum file, like the Node.js step
# above; pinned because the URLs embed the version (the
# directory component is the major.minor prefix).  Bump the
# pinned version here to update.
RUN v="1.12.6" \
    && case "$(uname -m)" in \
        x86_64) arch=x64 ;; \
        aarch64) arch=aarch64 ;; \
        *) echo "unsupported architecture: $(uname -m)"; exit 1 ;; \
    esac \
    && f="julia-${v}-linux-$(uname -m).tar.gz" \
    && cd /tmp \
    && curl -fsSL -O \
        "https://julialang-s3.julialang.org/bin/linux/${arch}/${v%.*}/${f}" \
    && curl -fsSL \
        "https://julialang-s3.julialang.org/bin/checksums/julia-${v}.sha256" \
        | awk -v f="${f}" '$2 == f' \
        | sha256sum -c - \
    && tar -xzf "${f}" -C /opt \
    && rm -f "${f}" \
    && ln -s "/opt/julia-${v}/bin/julia" /usr/local/bin/julia

# Generate the en_US.UTF-8 locale.  The locales package is
# already present (postgresql-18 depends on it) but ships with
# every locale commented out in /etc/locale.gen, so the image
# only has the C/POSIX/C.utf8 locales built into glibc; tools
# such as PostgreSQL's initdb and CREATE DATABASE expect
# en_US.UTF-8 to exist.  A separate layer near the end, like
# the MySQL one above, so the earlier layers' build caches
# survive.
RUN sed -i 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
        /etc/locale.gen \
    && locale-gen

# AWS CLI v2 from the official installer zip, AWS's supported
# distribution channel.  The zip name embeds the architecture
# exactly as uname -m reports it (x86_64, aarch64), so both
# amd64 and arm64 work without a case statement.  The installer
# places the tools under /usr/local/aws-cli and links aws and
# aws_completer into /usr/local/bin.
RUN cd /tmp \
    && f="awscli-exe-linux-$(uname -m).zip" \
    && curl -fsSL -O "https://awscli.amazonaws.com/${f}" \
    && unzip -q "${f}" \
    && ./aws/install \
    && rm -rf "${f}" aws

# Terraform from HashiCorp's apt repository, set up like the
# GitHub CLI step above; the repository tracks current releases
# and publishes both amd64 and arm64 packages.  HashiCorp
# serves its signing key ASCII-armored, hence the gpg --dearmor
# step (gnupg comes from the first layer).  Terraform is under
# the Business Source License since 1.6; the OpenTofu step
# below installs the open-source fork.
RUN key=/etc/apt/keyrings/hashicorp-archive-keyring.gpg \
    && curl -fsSL https://apt.releases.hashicorp.com/gpg \
        | gpg --dearmor -o "${key}" \
    && chmod a+r "${key}" \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=${key}]" \
        "https://apt.releases.hashicorp.com noble main" \
        > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends terraform \
    && rm -rf /var/lib/apt/lists/*

# OpenTofu (tofu), the open-source Terraform fork, from its
# packagecloud apt repository, following the project's own
# install documentation: the repository is signed with two keys
# (the OpenTofu project key, distributed in binary form, and
# the packagecloud repository key, ASCII-armored), so both are
# installed and listed in signed-by.  The "any" suite serves
# every deb-based distribution.
RUN k1=/etc/apt/keyrings/opentofu.gpg \
    && k2=/etc/apt/keyrings/opentofu-repo.gpg \
    && curl -fsSL -o "${k1}" https://get.opentofu.org/opentofu.gpg \
    && curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey \
        | gpg --dearmor -o "${k2}" \
    && chmod a+r "${k1}" "${k2}" \
    && echo "deb [signed-by=${k1},${k2}]" \
        "https://packages.opentofu.org/opentofu/tofu/any/ any main" \
        > /etc/apt/sources.list.d/opentofu.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends tofu \
    && rm -rf /var/lib/apt/lists/*

# Ansible from the ansible/ansible PPA, the repository the
# official install guide points Ubuntu users at: Ubuntu 24.04
# freezes ansible at 9.2 (ansible-core 2.16), while the PPA
# tracks current releases (the packages are Architecture: all,
# so every architecture is covered).  Launchpad serves PPA
# signing keys through keyserver.ubuntu.com, ASCII-armored,
# hence the gpg --dearmor step like the Terraform one above;
# the fingerprint is the PPA's signing_key_fingerprint from the
# Launchpad API.  The "ansible" package pulls in ansible-core
# and adds the community collections.
RUN key=/etc/apt/keyrings/ansible-archive-keyring.gpg \
    && fpr=6125E2A8C77F2818FB7BD15B93C4A3FD7BB9C367 \
    && curl -fsSL \
        "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${fpr}" \
    | gpg --dearmor -o "${key}" \
    && chmod a+r "${key}" \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=${key}]" \
        "https://ppa.launchpadcontent.net/ansible/ansible/ubuntu" \
        "noble main" \
        > /etc/apt/sources.list.d/ansible.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends ansible \
    && rm -rf /var/lib/apt/lists/*

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
