#!/bin/sh
# Session Manager plugin for the AWS CLI
# (session-manager-plugin, needed by "aws ssm start-session"),
# from AWS's official packages.  The URL's directory component
# names both the package format and the architecture, so pick
# the one matching this image: AWS labels the .deb directories
# ubuntu_* and the .rpm ones linux_*.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

base="https://s3.amazonaws.com/session-manager-downloads/plugin/latest"

if command -v apt-get > /dev/null 2>&1; then
    d=$(arch_alias ubuntu_64bit ubuntu_arm64)
    p=/tmp/session-manager-plugin.deb
    curl -fsSL -o "${p}" "${base}/${d}/session-manager-plugin.deb"
    apt-get update
    apt-get install -y --no-install-recommends "${p}"
    rm -rf /var/lib/apt/lists/*
else
    d=$(arch_alias linux_64bit linux_arm64)
    p=/tmp/session-manager-plugin.rpm
    curl -fsSL -o "${p}" "${base}/${d}/session-manager-plugin.rpm"
    rpm -i "${p}"
fi
rm -f "${p}"
