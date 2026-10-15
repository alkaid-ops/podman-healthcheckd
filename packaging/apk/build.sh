#!/bin/sh
# Assemble a signed Alpine (.apk) package for podman-healthcheckd.
#
# Runs inside an Alpine container with the repository mounted at /src. The
# statically linked musl binary must already exist at
#   target/x86_64-unknown-linux-musl/release/podman-healthcheckd
#
# If $APK_PRIVKEY holds an RSA private key (PEM), it is used for signing so that
# releases share a stable key; otherwise a throwaway key is generated. In both
# cases the matching public key is copied to the repository root so it can be
# published alongside the package.
#
# Usage: VERSION=v0.1.4 [APK_PRIVKEY=...] sh packaging/apk/build.sh

set -eu

SRC="${SRC:-/src}"
PKGDIR="$SRC/packaging/apk"
BIN="$SRC/target/x86_64-unknown-linux-musl/release/podman-healthcheckd"
PACKAGER="Franz Geffke <mail@gofranz.com>"
KEY_NAME="${APK_PRIVKEY_NAME:-podman-healthcheckd.rsa}"
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

# abuild uses $PACKAGER to name the signing key and to stamp the package.
if ! grep -q '^PACKAGER=' /etc/abuild.conf 2>/dev/null; then
	echo "PACKAGER=\"$PACKAGER\"" >> /etc/abuild.conf
fi

mkdir -p /var/cache/distfiles /home/builder/.abuild
chmod 775 /var/cache/distfiles
chgrp abuild /var/cache/distfiles

if [ -n "${APK_PRIVKEY:-}" ]; then
	echo "Signing with provided key: $KEY_NAME" >&2
	printf '%s\n' "$APK_PRIVKEY" > "/home/builder/.abuild/$KEY_NAME"
	chmod 600 "/home/builder/.abuild/$KEY_NAME"
	echo "PACKAGER_PRIVKEY=\"/home/builder/.abuild/$KEY_NAME\"" \
		>> /home/builder/.abuild/abuild.conf
	openssl rsa -in "/home/builder/.abuild/$KEY_NAME" \
		-pubout -out "/home/builder/.abuild/$KEY_NAME.pub" >/dev/null
else
	echo "APK_PRIVKEY not set; generating a throwaway signing key" >&2
	su builder -c 'abuild-keygen -a -n'
	KEY_NAME="$(basename "$(ls /home/builder/.abuild/*.rsa | head -n 1)")"
fi

chown -R builder:builder /home/builder/.abuild

# Stage the prebuilt binary and stamp the version into the recipe.
cp "$BIN" "$PKGDIR/podman-healthcheckd"
sed -i "s/^pkgver=.*/pkgver=$VERSION/" "$PKGDIR/APKBUILD"
chown -R builder:builder "$PKGDIR"

su builder -c "cd $PKGDIR && abuild -r"

find /home/builder/packages -name '*.apk' -exec cp {} "$SRC/" \;
cp "/home/builder/.abuild/$KEY_NAME.pub" "$SRC/"
chmod a+r "$SRC"/*.apk "$SRC/$KEY_NAME.pub"
ls -l "$SRC"/*.apk "$SRC/$KEY_NAME.pub"
