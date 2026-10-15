#!/bin/sh
# Assemble a signed Alpine (.apk) package for podman-healthcheckd.
#
# This is meant to run inside an Alpine container with the repository mounted
# at /src. The statically linked musl binary must already exist at
#   target/x86_64-unknown-linux-musl/release/podman-healthcheckd
# and the resulting package is copied to the repository root.
#
# Usage: VERSION=v0.1.4 sh packaging/apk/build.sh

set -eu

SRC="${SRC:-/src}"
PKGDIR="$SRC/packaging/apk"
BIN="$SRC/target/x86_64-unknown-linux-musl/release/podman-healthcheckd"
PACKAGER="Franz Geffke <mail@gofranz.com>"
VERSION="${VERSION:-}"
VERSION="${VERSION#v}"

if [ -z "$VERSION" ]; then
	echo "error: VERSION is not set" >&2
	exit 1
fi

if [ ! -x "$BIN" ]; then
	echo "error: missing binary: $BIN" >&2
	exit 1
fi

apk add --no-cache alpine-sdk sudo >/dev/null

# abuild refuses to run as root, so create an unprivileged builder account.
adduser -D builder
addgroup builder abuild
echo "%abuild ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# abuild uses $PACKAGER to name the signing key.
if ! grep -q '^PACKAGER=' /etc/abuild.conf 2>/dev/null; then
	echo "PACKAGER=\"$PACKAGER\"" >> /etc/abuild.conf
fi

mkdir -p /var/cache/distfiles
chmod 775 /var/cache/distfiles
chgrp abuild /var/cache/distfiles

# Stage the prebuilt binary and stamp the version into the recipe.
cp "$BIN" "$PKGDIR/podman-healthcheckd"
sed -i "s/^pkgver=.*/pkgver=$VERSION/" "$PKGDIR/APKBUILD"
chown -R builder:builder "$PKGDIR"

su builder -c 'abuild-keygen -a -n'
su builder -c "cd $PKGDIR && abuild -r"

find /home/builder/packages -name '*.apk' -exec cp {} "$SRC/" \;
chmod a+r "$SRC"/*.apk
ls -l "$SRC"/*.apk
