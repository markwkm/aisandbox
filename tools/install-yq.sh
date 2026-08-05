#!/bin/sh
# mikefarah's yq (Go YAML processor).  Ubuntu's "yq" package is
# the unrelated Python jq wrapper, so install the yq that most
# documentation assumes, from the latest release.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

url="https://github.com/mikefarah/yq/releases/latest/download"
arch=$(arch_alias amd64 arm64)

curl -fsSL -o /usr/local/bin/yq "${url}/yq_linux_${arch}"
chmod +x /usr/local/bin/yq
