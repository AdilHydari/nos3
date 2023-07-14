#!/bin/bash -i
#
# Convenience script for NOS3 development
# Use with the Dockerfile in the deployment repository
# https://docs.docker.com/engine/install/ubuntu/
#

SCRIPT_DIR=$(cd `dirname $0` && pwd)
BASE_DIR=$(cd `dirname $SCRIPT_DIR`/.. && pwd)
if [ -f "/etc/redhat-release" ]; then
    # https://github.com/containers/podman/issues/14284#issuecomment-1130113553
    # sudo sed -i 's/runtime = "runc"/runtime = "crun" # "runc"/g' /usr/share/containers/containers.conf 
    DFLAGS="sudo docker run --rm --group-add keep-groups -it"
else
    DFLAGS="docker run --rm -it"
fi

$DFLAGS -v $BASE_DIR:$BASE_DIR -w $BASE_DIR -it ivvitc/nos3 make
