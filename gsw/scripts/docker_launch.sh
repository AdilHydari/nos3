#!/bin/bash -i
#
# Convenience script for NOS3 development
# Use with the Dockerfile in the deployment repository
# https://docs.docker.com/engine/install/ubuntu/
#

SCRIPT_DIR=$(cd `dirname $0` && pwd)
BASE_DIR=$(cd `dirname $SCRIPT_DIR`/.. && pwd)
FSW_DIR=$BASE_DIR/fsw/build/exe/cpu1
GSW_DIR=$BASE_DIR/gsw/cosmos
if [ -f "/etc/redhat-release" ]; then
    # https://github.com/containers/podman/issues/14284#issuecomment-1130113553
    # sudo sed -i 's/runtime = "runc"/runtime = "crun" # "runc"/g' /usr/share/containers/containers.conf 
    DFLAGS="sudo docker run --rm --group-add keep-groups -it"
    DNETWORK="sudo docker network"
else
    DFLAGS="docker run --rm -it"
    DNETWORK="docker network"
fi
SIM_DIR=$BASE_DIR/sims/build
SIM_BIN=$SIM_DIR/bin
SIMS=$(cd $SIM_BIN; ls nos3*simulator)

# Debugging
#echo "Script directory = " $SCRIPT_DIR
#echo "Base directory   = " $BASE_DIR
#echo "DFLAGS           = " $DFLAGS
#echo "FSW directory    = " $FSW_DIR
#echo "GSW directory    = " $GSW_DIR
#echo "Sim directory    = " $SIM_BIN
#echo "Sim list         = " $SIMS
#exit

echo "Make data folders..."
# FSW Side
mkdir $FSW_DIR/data 2> /dev/null
mkdir $FSW_DIR/data/cam 2> /dev/null
mkdir $FSW_DIR/data/evs 2> /dev/null
mkdir $FSW_DIR/data/hk 2> /dev/null
mkdir $FSW_DIR/data/inst 2> /dev/null
# GSW Side
mkdir /tmp/data 2> /dev/null
mkdir /tmp/data/cam 2> /dev/null
mkdir /tmp/data/evs 2> /dev/null
mkdir /tmp/data/hk 2> /dev/null
mkdir /tmp/data/inst 2> /dev/null
mkdir /tmp/uplink 2> /dev/null
cp $BASE_DIR/fsw/build/exe/cpu1/cf/cfe_es_startup.scr /tmp/uplink/tmp0.so 2> /dev/null
cp $BASE_DIR/fsw/build/exe/cpu1/cf/sample.so /tmp/uplink/tmp1.so 2> /dev/null

echo "Create docker network..."
$DNETWORK create \
    --driver=bridge \
    --subnet=192.168.42.0/24 \
    --gateway=192.168.42.1 \
    SC01
#$DFLAGS --network=SC01 --name testcon nos3 /bin/bash &
echo ""

echo "42..."
cd /opt/nos3/42/
rm -rf NOS3InOut
cp -r $BASE_DIR/sims/cfg/InOut /opt/nos3/42/NOS3InOut
xhost +local:*
gnome-terminal --tab --title="42" -- $DFLAGS -e DISPLAY=$DISPLAY -v /opt/nos3/42/NOS3InOut:/opt/nos3/42/NOS3InOut -v /tmp/.X11-unix:/tmp/.X11-unix:ro --name fortytwo --network=SC01 -w /opt/nos3/42 -t ivvitc/nos3 /opt/nos3/42/42 NOS3InOut
echo ""

echo "COSMOS Ground Station..."
cd $BASE_DIR/gsw/cosmos
export MISSION_NAME=$(echo "NOS3")
export PROCESSOR_ENDIANNESS=$(echo "LITTLE_ENDIAN")
$DFLAGS -e DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix:ro -e QT_X11_NO_MITSHM=1 \
    --volume $GSW_DIR:/cosmos/cosmos \
    --volume $BASE_DIR/components:/COMPONENTS -w /cosmos/cosmos -d --name cosmos --network=SC01 \
    ballaerospace/cosmos /bin/bash -c 'ruby Launcher -c nos3_launcher.txt --system nos3_system.txt && true' # true is necessary to avoid setpgrp error
echo ""

echo "Flight Software..."
cd $FSW_DIR
gnome-terminal --title="NOS3 Flight Software" -- $DFLAGS -v $FSW_DIR:$FSW_DIR --name nos-fsw -h nos-fsw --network=SC01 -w $FSW_DIR --sysctl fs.mqueue.msg_max=1500 ivvitc/nos3 ./core-cpu1 -R PO &
# Note: Can keep open if desired after a new gnome-profile is manually created
#gnome-terminal --title="NOS3 Flight Software" --window-with-profile=KeepOpen -- $DFLAGS -v $FSW_DIR:$FSW_DIR --name nos-fsw -h nos-fsw --network=SC01 -w $FSW_DIR --sysctl fs.mqueue.msg_max=1500 ivvitc/nos3 ./core-cpu1 -R PO &
echo ""

echo "Simulators..."
cd $SIM_BIN
gnome-terminal --tab --title="NOS Engine Server" -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_engine_server -h nos_engine_server --network=SC01 -w $SIM_BIN ivvitc/nos3 /usr/bin/nos_engine_server_standalone -f $SIM_BIN/nos_engine_server_config.json
gnome-terminal --tab --title='NOS Terminal'      -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_terminal      --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator stdio-terminal
gnome-terminal --tab --title='NOS UDP Terminal'  -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_udp_terminal  --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator udp-terminal
gnome-terminal --tab --title='42 Truth Sim'      -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name truth42sim        --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator truth42sim
gnome-terminal --tab --title='CAM Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name cam_sim           --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-cam-simulator
gnome-terminal --tab --title='CSS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name css_sim           --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-css-simulator
gnome-terminal --tab --title='EPS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name eps_sim           --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-eps-simulator
gnome-terminal --tab --title="FSS Sim"           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name fss_sim           --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator generic-fss-sim
gnome-terminal --tab --title='IMU Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name imu_sim           --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-imu-simulator
gnome-terminal --tab --title='GPS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name gps_sim           --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-gps-simulator
gnome-terminal --tab --title='RW Sim'            -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name rw_sim            --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-reactionwheel-simulator
gnome-terminal --tab --title='Radio Sim'         -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name radio_sim         --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-radio-simulator
gnome-terminal --tab --title='Sample Sim'        -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name sample_sim        --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-sample-simulator
gnome-terminal --tab --title='Torquer Sim'       -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name torquer_sim       --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-torquer-simulator
sleep 5
gnome-terminal --tab --title="NOS Time Driver"   -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_time_driver   --network=SC01 -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator time
echo ""
