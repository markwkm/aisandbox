#!/bin/sh
# shunit2 shell-script unit-test framework (Apache License
# 2.0), a single upstream script, pinned like actionlint.  Bump
# the pinned version here to update.
set -eu

v="2.1.8"
url="https://raw.githubusercontent.com/kward/shunit2/v${v}"

curl -fsSL -o /usr/local/bin/shunit2 "${url}/shunit2"
chmod 755 /usr/local/bin/shunit2
