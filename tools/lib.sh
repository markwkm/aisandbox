# shellcheck shell=sh
#
# Shell helpers shared by the aisandbox install scripts.  Each
# script sources this file:
#
#   . /opt/aisandbox/lib.sh
#
# and runs under "set -eu", so a helper reports failure by
# exiting non-zero and the calling script stops there, failing
# the build step.

# arch_alias X86_64_NAME AARCH64_NAME
#
# Print the argument matching this machine's architecture.
# Download URLs spell the architecture a dozen different ways
# (amd64, x64, x86_64, aarch64, arm64, ...), so each caller
# passes the pair of names its own URL uses.  Anything other
# than the two supported architectures fails the build instead
# of fetching a binary that cannot run.
#
# Callers use this in a command substitution, where the exit
# below ends only the substitution's subshell; the assignment
# then carries its non-zero status, which "set -e" turns into
# the exit that stops the script.
arch_alias() {
    case "$(uname -m)" in
        x86_64) echo "$1" ;;
        aarch64) echo "$2" ;;
        *)
            echo "unsupported architecture: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

# verify_sha256 FILE
#
# Read a "checksum  filename" list on standard input, keep the
# line naming FILE, and check FILE against it.  sha256sum -c
# exits non-zero when it is handed no checksum line at all, so
# a truncated checksum list, or one that has stopped naming
# FILE, fails the build rather than silently skipping
# verification.
verify_sha256() {
    awk -v f="$1" '$2 == f' | sha256sum -c -
}
