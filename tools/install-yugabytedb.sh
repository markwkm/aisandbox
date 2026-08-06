#!/bin/sh
# YugabyteDB, from the official binary tarball.  Upstream keeps
# a long-term support line (LTS) and a shorter-lived standard
# term support line (STS); this pins the LTS one.  Both the
# version and upstream's build number are part of the file
# name, so both are pinned here.  Bump the pair here to update;
# the current version and build of each line are listed at
# https://docs.yugabyte.com/preview/releases/ybdb-releases/
#
# Upstream publishes no checksum file beside the tarball, so
# unlike the other downloads in tools/ this one is only as
# trustworthy as its TLS connection.
#
# Upstream names the x86_64 build linux-x86_64 and the arm64
# one el8-aarch64.  The x86_64 binaries need glibc 2.28, which
# is exactly what Oracle Linux 8 has, and the arm64 ones are
# the build upstream makes for EL8, so either flavor can run
# them.
# post_install.sh is the setup step upstream's own install
# instructions run from the unpacked directory.  The
# unversioned /opt/yugabyte symlink gives the commands below a
# stable path, as /opt/oracle/instantclient does in
# Containerfile.ubuntu.
#
# The unpacked tree is handed to the uid-1000 agent user, so it
# can be written to from inside the sandbox without root.  The
# owner is given numerically because that user does not have
# the same name in both flavors, and does not exist yet at this
# point in Containerfile.oracle, which creates it further down;
# 1000:1000 is also what start-aisandbox maps the host user
# onto at run time.  The chmod keeps the tree readable and
# executable for everyone else, including the oracle flavor's
# database user.
#
# Only selected commands are linked onto the PATH: the
# release's bin directory also holds generic names (openssl,
# redis-cli, configure, cqlsh) that would shadow system
# commands if the whole directory were added.  yb-ctl is left
# out because it starts with "#!/usr/bin/env python" and
# neither image has a bare "python" command; yugabyted
# supersedes it.
#
# yugabyted puts itself in the background, so no foreground
# command is needed as with the other servers here:
#   yugabyted start --base_dir="${HOME}/yugabyte-data"
#   ysqlsh                  # YSQL, port 5433
#   ycqlsh                  # YCQL, port 9042
#   yugabyted stop --base_dir="${HOME}/yugabyte-data"
# The sandbox shares the host network, so those ports and the
# web UIs yugabyted starts are bound on the host as well.
set -eu

# shellcheck source-path=SCRIPTDIR source=lib.sh
. /opt/aisandbox/lib.sh

v="2025.2.5.2"
b="b5"
base="https://software.yugabyte.com/releases/${v}"
f="yugabyte-${v}-${b}-$(arch_alias linux-x86_64 el8-aarch64).tar.gz"

cd /tmp
curl -fsSL -O "${base}/${f}"
tar -xzf "${f}" -C /opt
rm -f "${f}"
"/opt/yugabyte-${v}/bin/post_install.sh"
chmod -R a+rX "/opt/yugabyte-${v}"
chown -R 1000:1000 "/opt/yugabyte-${v}"
ln -s "/opt/yugabyte-${v}" /opt/yugabyte
chown -h 1000:1000 /opt/yugabyte

for c in yugabyted ysqlsh ycqlsh yb-admin yb-master yb-tserver \
    yb-ts-cli; do
    ln -s "/opt/yugabyte/bin/${c}" "/usr/local/bin/${c}"
done

# Fail the build here rather than ship binaries that cannot run.
yb-master --version > /dev/null
