#!/bin/sh
# Julia from the official julialang.org binary tarball, which
# unpacks into a version-named directory under /opt; the
# symlink puts the julia command on the PATH.  Verified against
# the release's published checksum file, and pinned because the
# URLs embed the version (the directory component is the
# major.minor prefix, and names the architecture differently
# from the tarball itself).  Bump the pinned version here to
# update.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

v="1.12.6"
base="https://julialang-s3.julialang.org/bin"
arch=$(arch_alias x64 aarch64)
f="julia-${v}-linux-$(uname -m).tar.gz"

cd /tmp
curl -fsSL -O "${base}/linux/${arch}/${v%.*}/${f}"
curl -fsSL "${base}/checksums/julia-${v}.sha256" \
    | verify_sha256 "${f}"
tar -xzf "${f}" -C /opt
rm -f "${f}"
ln -s "/opt/julia-${v}/bin/julia" /usr/local/bin/julia
