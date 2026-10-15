#!/bin/sh
# $1 is the number of instances that remain after this operation:
#   0 = final removal, 1 = upgrade. Only sweep on final removal.
[ "${1:-}" = 0 ] || exit 0

# Safety net: remove any of our symlinks the preun hook may have missed.
for p in \
	/etc/init.d/podman-healthcheckd \
	/etc/conf.d/podman-healthcheckd \
	/etc/sv/podman-healthcheckd \
	/etc/dinit.d/podman-healthcheckd
do
	[ -L "$p" ] || continue
	case "$(readlink "$p")" in
		/usr/share/podman-healthcheckd/services/*) rm -f "$p" ;;
	esac
done

exit 0
