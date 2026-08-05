#!/bin/sh
# actionlint (GitHub Actions workflow linter), pinned because
# the release asset name embeds the version.  Bump the pinned
# version here to update.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

v="1.7.12"
url="https://github.com/rhysd/actionlint/releases/download/v${v}"
f="actionlint_${v}_linux_$(arch_alias amd64 arm64).tar.gz"

cd /tmp
curl -fsSL -O "${url}/${f}"
tar -xzf "${f}" actionlint
mv actionlint /usr/local/bin/
rm -f "${f}"
