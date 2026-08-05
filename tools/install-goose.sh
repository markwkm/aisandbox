#!/bin/sh
# goose (Block).  CONFIGURE=false skips the interactive setup
# that the install script otherwise runs.  The released binary
# needs glibc 2.28 or newer.
#
# The installer is downloaded to a file rather than piped into
# a shell: a pipeline reports the status of its last command,
# so a failed download would feed an empty script to a shell
# that exits 0, leaving an image with no goose in it and a
# build that looks like it succeeded.
set -eu

url="https://github.com/block/goose/releases/download/stable"

cd /tmp
curl -fsSL -O "${url}/download_cli.sh"
GOOSE_BIN_DIR=/usr/local/bin CONFIGURE=false bash download_cli.sh
rm -f download_cli.sh
