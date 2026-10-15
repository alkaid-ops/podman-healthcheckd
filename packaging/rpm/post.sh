#!/bin/sh

# Wire up the service definition for the init system that is present.
# Do NOT enable or start anything: that is the administrator's choice.
SCRIPT=/usr/share/podman-healthcheckd/detect-init.sh
if [ -x "$SCRIPT" ]; then
	"$SCRIPT" install || :
fi

exit 0
