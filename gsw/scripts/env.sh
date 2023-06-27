#!/bin/bash
#
# Convenience script for NOS3 development
#

export SCRIPT_DIR=$(cd `dirname $0` && pwd)
echo "Script directory = " $SCRIPT_DIR

export BASE_DIR=$(cd `dirname $SCRIPT_DIR`/.. && pwd)
echo "Base directory   = " $BASE_DIR

export FSW_DIR=$BASE_DIR/fsw/build/exe/cpu1
echo "FSW directory    = " $FSW_DIR

export GSW_DIR=$BASE_DIR/gsw/cosmos
echo "GSW directory    = " $GSW_DIR

export SIM_DIR=$BASE_DIR/sims/build
echo "Sim directory    = " $SIM_DIR

export SIM_BIN=$SIM_DIR/bin
echo "Sim bin          = " $SIM_BIN

if [ -f "/etc/redhat-release" ]; then
    # https://github.com/containers/podman/issues/14284#issuecomment-1130113553
    # sudo sed -i 's/runtime = "runc"/runtime = "crun" # "runc"/g' /usr/share/containers/containers.conf 
    export DFLAGS="--rm --group-add keep-groups -it"
else
    export DFLAGS="--rm -it"
fi
echo "DFLAGS flags     = " $DFLAGS
