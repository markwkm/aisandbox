#!/bin/sh
# CockroachDB, from the official binary tarball, pinned because
# the URL embeds the version and verified against the checksum
# Cockroach Labs publishes beside it.  Bump the pinned version
# here to update; the current production releases are listed at
# https://www.cockroachlabs.com/docs/releases/
#
# The GEOS libraries that back the spatial functions ship in the
# tarball's lib directory, and /usr/local/lib/cockroach is where
# the cockroach binary looks for them, as the install
# documentation describes.  The tarball's license and
# third-party notices are kept beside them, since CockroachDB is
# under the CockroachDB Software License rather than a
# permissive one.
#
# The amd64 binary needs nothing newer than glibc 2.17 and
# links only against the C library, so it runs on Oracle
# Linux 8 as well as Ubuntu.  There is no init system
# here, so run a single-node cluster in the foreground:
#   cockroach start-single-node --insecure \
#       --store="${HOME}/cockroach-data" \
#       --listen-addr=localhost:26257 --http-addr=localhost:8080
# then reach it with "cockroach sql --insecure" or with any
# PostgreSQL client on port 26257.  The sandbox shares the host
# network, so both ports are bound on the host as well.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

v="26.1.6"
base="https://binaries.cockroachdb.com"
d="cockroach-v${v}.linux-$(arch_alias amd64 arm64)"

cd /tmp
curl -fsSL -O "${base}/${d}.tgz"
curl -fsSL "${base}/${d}.tgz.sha256sum" | verify_sha256 "${d}.tgz"
tar -xzf "${d}.tgz"
install -m 755 "${d}/cockroach" /usr/local/bin/cockroach
mkdir -p /usr/local/lib/cockroach /usr/local/share/doc/cockroach
install -m 755 "${d}/lib/libgeos.so" "${d}/lib/libgeos_c.so" \
    /usr/local/lib/cockroach/
install -m 644 "${d}/LICENSE" "${d}/THIRD-PARTY-NOTICES.txt" \
    /usr/local/share/doc/cockroach/
rm -rf "${d}" "${d}.tgz"

# Fail the build here rather than ship a binary that cannot run.
cockroach version > /dev/null
