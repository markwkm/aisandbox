#!/bin/sh
# Install the named Python tools as isolated uv tools whose
# commands are reachable system-wide: UV_TOOL_DIR collects one
# virtual environment per tool under /opt, and UV_TOOL_BIN_DIR
# puts the commands in /usr/local/bin.  The tree is then made
# readable and traversable for everyone, since the build runs
# as root and the image runs as an unprivileged user.
#
# Usage: install-uv-tools.sh TOOL [TOOL ...]
set -eu

if [ $# -eq 0 ]; then
    echo "usage: install-uv-tools.sh TOOL [TOOL ...]" >&2
    exit 1
fi

export UV_TOOL_DIR=/opt/uv-tools
export UV_TOOL_BIN_DIR=/usr/local/bin

for t in "$@"; do
    uv tool install --python 3.12 "${t}"
done

chmod -R a+rX /opt/uv-tools
