#!/bin/sh
# Rust via rustup, installed system-wide and read-only.  The
# default profile includes clippy (linter) and rustfmt.
#
# Only RUSTUP_HOME is meant to stay in the image's environment
# (the Containerfile sets it); CARGO_HOME stays at its ~/.cargo
# default at runtime so per-user cargo builds can write their
# registry.
#
# The installer is downloaded to a file rather than piped into
# a shell, for the reason install-goose.sh gives.
set -eu

cd /tmp
curl -fsSL -o rustup-init.sh https://sh.rustup.rs
RUSTUP_HOME=/opt/rust CARGO_HOME=/opt/rust \
    sh rustup-init.sh -y --no-modify-path --profile default
rm -f rustup-init.sh
chmod -R a+rX /opt/rust
