#!/bin/sh
# hadolint (Containerfile/Dockerfile linter), from the latest
# release's statically linked binary.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

url="https://github.com/hadolint/hadolint/releases/latest/download"
arch=$(arch_alias x86_64 arm64)

curl -fsSL -o /usr/local/bin/hadolint \
    "${url}/hadolint-linux-${arch}"
chmod +x /usr/local/bin/hadolint
