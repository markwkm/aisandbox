==========
AI Sandbox
==========

A container image for running AI coding agents in a sandbox, isolated from
the host system.  The default image is based on Ubuntu supposedly the most
widely supported distro for AI tools; a variant based on Oracle's official
Oracle Database Free image adds a running Oracle database (see `Oracle
variant`_ below).

Agents installed (command names in parentheses):

* Claude Code (``claude``)
* Kiro CLI (``kiro-cli``)
* opencode (``opencode``)
* OpenClaw (``openclaw``)
* goose (``goose``)
* pi (``pi``)
* aider (``aider``)

The image also carries common development tools plus linters and formatters
for C/C++, Python, Rust, Go, shell, YAML, Markdown, reStructuredText, SQL,
JavaScript, CSS, HTML, JSON, XML, Lua, Perl, prose, and Containerfiles (see
Containerfile.ubuntu for the full list).  Also included are the Rust and Go
toolchains, meson and ninja, the docutils rst2* tools and sphinx, and the
DocBook toolchain the PostgreSQL documentation build requires.

Files
=====

``Containerfile.ubuntu``
    Default image definition.

``Containerfile.oracle``
    Variant with Oracle Database Free, on Oracle Linux 8; carries the same
    tools where Oracle Linux packaging allows (its header lists what is
    left out).

``start-aisandbox``
    Starts the sandbox container detached in the background with the
    appropriate mounts and environment.

``open-shell``
    Opens an interactive shell, or runs a command, in the running sandbox
    container.

``stop-aisandbox``
    Stops the sandbox container, which removes itself.

``update-aisandbox``
    Rebuilds an image from scratch so the base image, OS packages, and
    agents come in at current versions, then removes the replaced image.
    Builds ``Containerfile.ubuntu`` unless a flavor argument names another
    variant.

Building the image
==================

Build with podman::

    podman build --build-arg USERNAME="$(id -un)" \
        --build-arg USERSHELL="${SHELL}" \
        -t aisandbox -f Containerfile.ubuntu .

or with docker::

    docker build --build-arg USERNAME="$(id -un)" \
        --build-arg USERSHELL="${SHELL}" \
        -t aisandbox -f Containerfile.ubuntu .

The ``USERNAME`` build argument names the container user after the invoking
host user so absolute paths match on both sides; Claude Code and other
agents key per-project state (sessions, trust) on the working directory's
absolute path, and matching ``/home/<user>`` paths keep sessions resumable
on host and in the sandbox alike.

The build downloads all agents at their current versions; rebuild
periodically to pick up tool and OS security fixes (the agents'
self-updaters are disabled inside the image)::

    ./update-aisandbox

The update script rebuilds with ``--pull --no-cache`` so the base image and
every install step actually fetch current versions instead of reusing
cached layers, then removes the image it replaced.  A running container
stays on the old image until restarted with ``stop-aisandbox`` and
``start-aisandbox``.  A flavor argument selects another
``Containerfile.<flavor>`` and tags the image ``aisandbox-<flavor>``::

    ./update-aisandbox oracle

The Kiro CLI step installs an amd64-only .deb package.  On arm64 hosts,
replace that step with the zip noted in the Containerfile.ubuntu comments.

Starting a container
====================

Start the sandbox in the background::

    ./start-aisandbox

It prefers podman and falls back to docker, and leaves a container named
``aisandbox`` idling until stopped.  Each flavor gets its own container
name: a flavor argument (or ``AISANDBOX_FLAVOR``) makes ``start-aisandbox
oracle`` run the oracle image as ``aisandbox-oracle``, and points
``open-shell`` and ``stop-aisandbox`` at that container.  One container
per Containerfile can run at a time, and the flavors run side by side,
sharing the host network and the mounted source and agent state
directories.  Open as many shells in it as needed
(the host's login shell, as an unprivileged container user named after the
invoking host user)::

    ./open-shell

Any arguments are run instead of the shell::

    ./open-shell claude --version

The ``-r`` option runs as root inside the container instead, e.g. to
install extra packages::

    ./open-shell -r apt-get install -y strace

and ``-u`` runs as any other container user.

Stop the sandbox when done::

    ./stop-aisandbox

``start-aisandbox`` mounts the following from the host, creating missing
directories first:

* the source directory (``~/.local/src`` by default, overridable with a
  command-line argument or ``AISANDBOX_SRC``) read/write, and used as
  the working directory
* per-agent configuration, cache, and state directories (``~/.claude`` and
  ``~/.claude.json``, ``~/.kiro``, ``~/.config/opencode``, ``~/.openclaw``,
  ``~/.config/goose``, ``~/.pi``, ``~/.aider``, and friends), so logins and
  history persist across runs
* ``~/.aws`` read/write, for Kiro/Bedrock credentials and the AWS SSO token
  cache
* shell startup files (``~/.profile``, ``~/.bashrc``, ``~/.bash_profile``,
  ``~/.zshrc``, ``~/.zshenv``, and the other common sh/bash/zsh/ksh files,
  plus ``~/.cargo/env``), ``~/.gitconfig``, ``~/.quiltrc``,
  ``~/.aider.conf.yml``, and ``~/.config/nvim`` read-only, when they exist

API keys (``ANTHROPIC_API_KEY``, ``OPENAI_API_KEY``, ``GEMINI_API_KEY``,
``OPENROUTER_API_KEY``) are passed through only when set in the calling
environment.

To run a different image tag::

    AISANDBOX_IMAGE=localhost/aisandbox:test ./start-aisandbox

To mount a different source directory, pass it as an argument or set
``AISANDBOX_SRC`` (the argument takes precedence)::

    ./start-aisandbox "${HOME}/src"
    AISANDBOX_SRC="${HOME}/src" ./start-aisandbox

The source directory is mounted at the same absolute path inside the
container so per-project agent state stays resumable on both sides.

Oracle variant
==============

``Containerfile.oracle`` builds the sandbox on Oracle's official Oracle
Database Free image (``container-registry.oracle.com/database/free``,
Oracle Linux 8), so the container also runs an Oracle database.  Build it
with::

    ./update-aisandbox oracle

A flavor argument points the runtime scripts at the oracle image and its
container name, ``aisandbox-oracle``, which can run alongside the default
sandbox::

    ./start-aisandbox oracle
    ./open-shell oracle
    ./stop-aisandbox oracle

Setting ``AISANDBOX_FLAVOR=oracle`` instead (e.g. exported once per shell
session) works for all three scripts as well; the argument takes
precedence.

The image entrypoint starts the database; the first boot takes a few
minutes to create it, so wait for ``DATABASE IS READY TO USE!`` in
``podman logs -f aisandbox-oracle`` or for the image's healthcheck to
pass.  The container shares the host network like every flavor, so the
database listens on port 1521 on the host as well; the ``FREEPDB1``
pluggable database is reachable at ``//localhost:1521/FREEPDB1`` as
``system`` with the password ``oracle`` set in Containerfile.oracle.  The
full ``ORACLE_HOME`` is present, including ``sqlplus``, ``sqlldr``, and
the OCI headers and client libraries for building client programs.

The database runs as the image's ``oracle`` user; agent work happens as
the uid-1000 user named after the invoking host user, created at build
time, which ``open-shell`` selects by default.  The database user is
reachable with::

    ./open-shell oracle -u oracle

Database data lives in ``/opt/oracle/oradata`` inside the container and is
not persisted across container removal.

The variant carries the same tools as the Ubuntu image where Oracle
Linux 8 packaging and its glibc allow, including the MySQL and PostgreSQL
servers and client development files; the ``Containerfile.oracle`` header
lists what is left out (notably Kiro CLI and ast-grep) and what is
substituted.

Notes
=====

* Under rootless podman the script maps the invoking user to uid 1000
  (``--userns=keep-id``) so files created in the mounts keep sane ownership
  on both sides.  Under docker, ownership is only correct when the host uid
  is already 1000.
* ``~/.ssh`` is deliberately not mounted.  If agents need to push, prefer
  HTTPS with a fine-grained, per-repository token.
* The container has unrestricted network egress.  For unattended or
  auto-approving agent runs, consider adding an egress allowlist firewall.
* goose is started with ``GOOSE_DISABLE_KEYRING=1`` since the container has
  no D-Bus secret service; its secrets live in ``~/.config/goose``.
