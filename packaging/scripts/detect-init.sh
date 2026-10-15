#!/bin/sh
# Detect the init system present on this machine and wire up (or tear down)
# the matching podman-healthcheckd service definition.
#
# The service definitions live in $SERVICES_DIR and are owned by the package;
# this script only creates/removes symlinks pointing at them, so upgrades and
# removal work normally and nothing untracked is ever written.
#
# Usage:
#   detect-init.sh install   # detect + create the symlinks
#   detect-init.sh remove    # remove the symlinks we created
#   detect-init.sh detect    # print the detected init (debug)
#
# Override detection (useful in chroots / container image builds):
#   PODMAN_HEALTHCHECKD_INIT=openrc|runit|dinit|sysvinit|none

set -eu

SERVICES_DIR="${PODMAN_HEALTHCHECKD_SERVICES_DIR:-/usr/share/podman-healthcheckd/services}"

INITD=/etc/init.d/podman-healthcheckd
CONFD=/etc/conf.d/podman-healthcheckd
SVDIR=/etc/sv/podman-healthcheckd
DINITD=/etc/dinit.d/podman-healthcheckd

detect_init() {
	if [ -n "${PODMAN_HEALTHCHECKD_INIT:-}" ]; then
		printf '%s\n' "$PODMAN_HEALTHCHECKD_INIT"
		return 0
	fi
	# This project exists for systems without systemd: never touch systemd.
	if [ -d /run/systemd/system ]; then
		printf 'systemd\n'
		return 0
	fi
	if [ -d /run/openrc ] || command -v rc-status >/dev/null 2>&1; then
		printf 'openrc\n'
		return 0
	fi
	if [ -d /run/runit ] || command -v runsvdir >/dev/null 2>&1; then
		printf 'runit\n'
		return 0
	fi
	if [ -d /run/dinit ] || command -v dinitctl >/dev/null 2>&1; then
		printf 'dinit\n'
		return 0
	fi
	case "$(readlink -f /sbin/init 2>/dev/null || true)" in
		*/openrc-init) printf 'openrc\n' ;;
		*/runit-init) printf 'runit\n' ;;
		*/dinit) printf 'dinit\n' ;;
		*/sysvinit/*|/sbin/init) printf 'sysvinit\n' ;;
		*) printf 'none\n' ;;
	esac
}

# link <target> <linkpath>
link() {
	[ -e "$1" ] || return 0
	d="${2%/*}"
	[ -d "$d" ] || mkdir -p "$d"
	if [ -e "$2" ] || [ -L "$2" ]; then
		# Only replace our own stale symlink, never a foreign file.
		unlink_own "$2"
		[ -e "$2" ] && return 0
	fi
	ln -s "$1" "$2"
}

# Remove $1 only if it is a symlink pointing into our services directory.
unlink_own() {
	[ -L "$1" ] || return 0
	case "$(readlink "$1")" in
		"$SERVICES_DIR"/*) rm -f "$1" ;;
	esac
}

do_install() {
	case "$(detect_init)" in
		openrc)
			link "$SERVICES_DIR/openrc/podman-healthcheckd.initd" "$INITD"
			link "$SERVICES_DIR/openrc/podman-healthcheckd.confd" "$CONFD"
			;;
		sysvinit)
			link "$SERVICES_DIR/sysvinit/podman-healthcheckd" "$INITD"
			;;
		runit)
			link "$SERVICES_DIR/runit/podman-healthcheckd" "$SVDIR"
			;;
		dinit)
			link "$SERVICES_DIR/dinit/podman-healthcheckd" "$DINITD"
			;;
		*)
			# systemd or unknown: leave the definitions in place for the
			# user to wire up manually.
			;;
	esac
}

do_remove() {
	unlink_own "$INITD"
	unlink_own "$CONFD"
	unlink_own "$SVDIR"
	unlink_own "$DINITD"
}

case "${1:-}" in
	install) do_install ;;
	remove) do_remove ;;
	detect) detect_init ;;
	*)
		echo "usage: $0 {install|remove|detect}" >&2
		exit 2
		;;
esac
