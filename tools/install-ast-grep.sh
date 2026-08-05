#!/bin/sh
# ast-grep (structural code search and rewriting), from the
# latest release zip, which carries a Rust target triple in its
# name.  Only the ast-grep binary is extracted.
#
# Not installed from its @ast-grep/cli npm package: that
# package also links an "sg" alias, which would shadow
# /usr/bin/sg (setgroups, from the shadow suite) from npm's
# /usr/local prefix.
#
# The released binaries need glibc 2.34 or newer.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

url="https://github.com/ast-grep/ast-grep/releases/latest/download"
triple=$(arch_alias x86_64-unknown-linux-gnu \
    aarch64-unknown-linux-gnu)
f="app-${triple}.zip"

cd /tmp
curl -fsSL -O "${url}/${f}"
unzip -o "${f}" ast-grep -d /usr/local/bin
chmod +x /usr/local/bin/ast-grep
rm -f "${f}"
