#!/bin/sh
# AWS CLI v2 from the official installer zip, AWS's supported
# distribution channel.  The zip name embeds the architecture
# exactly as uname -m reports it (x86_64, aarch64), so no
# translation is needed.  The installer places the tools under
# /usr/local/aws-cli and links aws and aws_completer into
# /usr/local/bin.
set -eu

cd /tmp
f="awscli-exe-linux-$(uname -m).zip"
curl -fsSL -O "https://awscli.amazonaws.com/${f}"
unzip -q "${f}"
./aws/install
rm -rf "${f}" aws
