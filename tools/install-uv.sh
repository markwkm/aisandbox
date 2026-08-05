#!/bin/sh
# uv (Astral), installed the way its own install script does
# but into /usr/local/bin so any user can run it, and so the
# uv tool installs that follow can place their commands there
# too.  Downloaded to a file rather than piped into a shell,
# for the reason install-goose.sh gives.
set -eu

cd /tmp
curl -fsSL -o uv-installer.sh https://astral.sh/uv/install.sh
UV_INSTALL_DIR=/usr/local/bin sh uv-installer.sh
rm -f uv-installer.sh
