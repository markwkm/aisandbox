==========
AI Sandbox
==========

A container image for running AI coding agents in a sandbox, isolated from
the host system.  The image is based on Ubuntu supposedly the most widely
supported distro for AI tools.

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
the Containerfile for the full list).  Also included are the Rust and Go
toolchains, meson and ninja, the docutils rst2* tools and sphinx, and the
DocBook toolchain the PostgreSQL documentation build requires.

Files
=====

``Containerfile``
    Image definition.

``start-aisandbox``
    Starts the sandbox container detached in the background with the
    appropriate mounts and environment.

``shell-aisandbox``
    Opens an interactive shell, or runs a command, in the running sandbox
    container.

``stop-aisandbox``
    Stops the sandbox container, which removes itself.

``update-aisandbox``
    Rebuilds the image from scratch so the base image, OS packages, and
    agents come in at current versions, then removes the replaced image.

Building the image
==================

Build with podman::

    podman build --build-arg USERNAME="$(id -un)" \
        --build-arg USERSHELL="${SHELL}" \
        -t aisandbox -f Containerfile .

or with docker::

    docker build --build-arg USERNAME="$(id -un)" \
        --build-arg USERSHELL="${SHELL}" \
        -t aisandbox -f Containerfile .

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
``start-aisandbox``.

The Kiro CLI step installs an amd64-only .deb package.  On arm64 hosts,
replace that step with the zip noted in the Containerfile comments.

Starting a container
====================

Start the sandbox in the background::

    ./start-aisandbox

It prefers podman and falls back to docker, and leaves a container named
``aisandbox`` idling until stopped.  Open as many shells in it as needed
(the host's login shell, as an unprivileged container user named after the
invoking host user)::

    ./shell-aisandbox

Any arguments are run instead of the shell::

    ./shell-aisandbox claude --version

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
