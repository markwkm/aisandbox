#!/bin/sh
# shfmt (shell formatter), from its statically linked release
# binary, pinned because the asset name embeds the version.
# Bump the pinned version here to update.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

v="3.13.1"
url="https://github.com/mvdan/sh/releases/download/v${v}"
f="shfmt_v${v}_linux_$(arch_alias amd64 arm64)"

curl -fsSL -o /usr/local/bin/shfmt "${url}/${f}"
chmod +x /usr/local/bin/shfmt
