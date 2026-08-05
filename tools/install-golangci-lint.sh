#!/bin/sh
# golangci-lint, the standard Go meta-linter (bundles
# staticcheck and friends).  Bump the pinned version here to
# update.
#
# Downloaded directly instead of via the project's install.sh:
# that script's checksum lookup greps the checksums file by
# filename, which now also matches the release's
# "....tar.gz.sbom.json" asset, so it compares the tarball
# against the wrong hash and always fails.  The exact-match
# verification below checks the same published checksum
# correctly.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

v="2.12.2"
url="https://github.com/golangci/golangci-lint/releases/download/v${v}"
base="golangci-lint-${v}-linux-$(arch_alias amd64 arm64)"

cd /tmp
curl -fsSL -O "${url}/${base}.tar.gz"
curl -fsSL "${url}/golangci-lint-${v}-checksums.txt" \
    | verify_sha256 "${base}.tar.gz"
tar -xzf "${base}.tar.gz"
mv "${base}/golangci-lint" /usr/local/bin/
rm -rf "${base}" "${base}.tar.gz"
