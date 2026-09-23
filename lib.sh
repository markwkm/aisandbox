# shellcheck shell=sh
# shellcheck disable=SC2034
# (SC2034: the variables set here are read by the scripts that
# source this file.)
#
# Shell functions shared by the aisandbox scripts next to this
# file.  Each script resolves its own directory first, following
# a symlink back to the real script so the library is found when
# the script is reached through a symlink in PATH, and sources
# this file:
#
#   . "${DIR}/lib.sh"
#
# The scripts run under "set -eu", and DIR is the directory they
# and this file live in.

# select_flavor [ARG ...]
#
# Set FLAVOR, and the names that follow from it.  The flavor is
# ARG when it names a Containerfile.<flavor> next to the
# scripts, otherwise AISANDBOX_FLAVOR, otherwise ubuntu.  A
# function cannot shift its caller's arguments, so FLAVOR_SHIFT
# says how many it consumed, 0 or 1:
#
#   select_flavor "$@"
#   shift "${FLAVOR_SHIFT}"
#
# The ubuntu flavor's image and container are named plainly
# aisandbox, the other flavors' aisandbox-<flavor>, and
# AISANDBOX_IMAGE and AISANDBOX_NAME override them.  BASE names
# the base image the agent image is built on: the image name
# with -base appended, which stays a valid reference when
# AISANDBOX_IMAGE carries a tag.
select_flavor() {
    FLAVOR="${AISANDBOX_FLAVOR:-ubuntu}"
    FLAVOR_SHIFT=0
    if [ $# -ge 1 ] && [ -f "${DIR}/Containerfile.${1}" ]; then
        FLAVOR="$1"
        FLAVOR_SHIFT=1
    fi
    if [ "${FLAVOR}" = "ubuntu" ]; then
        IMAGE="${AISANDBOX_IMAGE:-aisandbox}"
        NAME="${AISANDBOX_NAME:-aisandbox}"
    else
        IMAGE="${AISANDBOX_IMAGE:-aisandbox-${FLAVOR}}"
        NAME="${AISANDBOX_NAME:-aisandbox-${FLAVOR}}"
    fi
    BASE="${IMAGE}-base"
}

# find_engine
#
# Set ENGINE to podman, or to docker when podman is not
# installed, and fail when neither is.
find_engine() {
    if command -v podman >/dev/null 2>&1; then
        ENGINE="podman"
    elif command -v docker >/dev/null 2>&1; then
        ENGINE="docker"
    else
        echo "error: neither podman nor docker is installed" >&2
        exit 1
    fi
}
