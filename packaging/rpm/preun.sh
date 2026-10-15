#!/bin/sh

# $1 is the number of instances that remain after this operation:
#   0 = final removal, 1 = upgrade. Only clean up on final removal.
if [ "${1:-}" = 0 ]; then
	SCRIPT=/usr/share/podman-healthcheckd/detect-init.sh
	if [ -x "$SCRIPT" ]; then
		"$SCRIPT" remove || :
	fi
fi

exit 0
