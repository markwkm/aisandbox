#!/bin/sh
# Go toolchain from the official go.dev binary tarball (gofmt
# and go vet come with it), for images whose distribution
# packages it too old or behind package modularity.  The
# tarball name and checksum come from the go.dev download
# metadata, whose first entry is the current stable release.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

arch=$(arch_alias amd64 arm64)

cd /tmp
json=$(curl -fsSL 'https://go.dev/dl/?mode=json')
f=$(printf '%s' "${json}" | jq -r --arg a "${arch}" \
    '.[0].files[] | select(.os=="linux" and .arch==$a
        and .kind=="archive") | .filename')
s=$(printf '%s' "${json}" | jq -r --arg a "${arch}" \
    '.[0].files[] | select(.os=="linux" and .arch==$a
        and .kind=="archive") | .sha256')
curl -fsSL -O "https://go.dev/dl/${f}"
printf '%s  %s\n' "${s}" "${f}" | verify_sha256 "${f}"
tar -xzf "${f}" -C /usr/local
rm -f "${f}"
ln -s /usr/local/go/bin/go /usr/local/bin/go
ln -s /usr/local/go/bin/gofmt /usr/local/bin/gofmt
