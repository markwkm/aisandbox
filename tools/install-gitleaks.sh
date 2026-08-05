#!/bin/sh
# gitleaks (secret scanner, to keep credentials out of
# commits), pinned like actionlint.  Bump the pinned version
# here to update.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

v="8.30.1"
url="https://github.com/gitleaks/gitleaks/releases/download/v${v}"
f="gitleaks_${v}_linux_$(arch_alias x64 arm64).tar.gz"

cd /tmp
curl -fsSL -O "${url}/${f}"
tar -xzf "${f}" gitleaks
mv gitleaks /usr/local/bin/
rm -f "${f}"
