#!/bin/sh
# Node.js 24 (openclaw requires >= 22.22.3; 24.x covers all the
# npm-installed agents), from the official nodejs.org binary
# tarball, unpacked into /usr/local; it ships node, npm, npx,
# and corepack.  NodeSource's apt repository, used previously,
# sits behind a Cloudflare challenge that answers plain HTTP
# clients with 403 (nodesource/distributions issue #1844),
# which broke builds.
#
# The tarball name embeds the version, so resolve it from the
# SHASUMS256.txt in the latest-v24.x directory and verify the
# download against that same file.
#
# nodejs.org builds its Linux binaries on RHEL 8, so they run
# on anything with glibc 2.28 or newer.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

base="https://nodejs.org/dist/latest-v24.x"
arch=$(arch_alias x64 arm64)

cd /tmp
curl -fsSL -O "${base}/SHASUMS256.txt"
f=$(awk -v a="${arch}" \
    '$2 ~ "^node-v.*-linux-" a "\\.tar\\.xz$" { print $2 }' \
    SHASUMS256.txt)
curl -fsSL -O "${base}/${f}"
verify_sha256 "${f}" < SHASUMS256.txt
tar -xJf "${f}" -C /usr/local --strip-components=1
rm -f "${f}" SHASUMS256.txt /usr/local/CHANGELOG.md \
    /usr/local/LICENSE /usr/local/README.md
