#!/bin/bash -i
#
# Convenience script for NOS3 development
# Use with the Dockerfile in the deployment repository
# https://docs.docker.com/engine/install/ubuntu/
#

SCRIPT_DIR=$(cd `dirname $0` && pwd)
BASE_DIR=$(cd `dirname $SCRIPT_DIR`/.. && pwd)
FSW_BIN=$BASE_DIR/fsw/build/exe/cpu1
SIM_DIR=$BASE_DIR/sims/build
SIM_BIN=$SIM_DIR/bin
SIMS=$(cd $SIM_BIN; ls nos3*simulator)

# Debugging
#echo "Script directory = " $SCRIPT_DIR
#echo "Base directory   = " $BASE_DIR
#echo "FSW directory    = " $FSW_BIN
#echo "Sim directory    = " $SIM_BIN
#echo "Sim list         = " $SIMS
#exit

#echo "Make /tmp folders..."
#mkdir /tmp/data 2> /dev/null
#mkdir /tmp/data/hk 2> /dev/null
#mkdir /tmp/uplink 2> /dev/null

echo "42..."
cd /opt/nos3/42/
rm -rf NOS3InOut
cp -r $BASE_DIR/sims/cfg/InOut /opt/nos3/42/NOS3InOut
xhost +local:*
gnome-terminal --tab --title="42" -- docker run -it -e DISPLAY=$DISPLAY -v /opt/nos3/42/NOS3InOut:/opt/nos3/42/NOS3InOut -v /tmp/.X11-unix:/tmp/.X11-unix:ro --network=host -w /opt/nos3/42 -t nos3 /opt/nos3/42/42 NOS3InOut
echo ""

echo "Simulators..."
#cd $SIM_BIN
gnome-terminal --tab --title="NOS Engine Server" -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --name nos_engine_server --network=host -w $SIM_BIN nos3 /usr/bin/nos_engine_server_standalone -f $SIM_BIN/nos_engine_server_config.json
docker exec nos_engine_server cat /proc/sys/fs/mqueue/msg_max
gnome-terminal --tab --title="NOS Time Driver" -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3 $SIM_BIN/nos3-single-simulator time
gnome-terminal --tab --title='NOS Terminal' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3 $SIM_BIN/nos3-single-simulator stdio-terminal
gnome-terminal --tab --title='NOS UDP Terminal' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3 $SIM_BIN/nos3-single-simulator udp-terminal
gnome-terminal --tab --title='CAM Sim' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-cam-simulator
gnome-terminal --tab --title='CSS Sim' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-generic-css-simulator
gnome-terminal --tab --title='EPS Sim' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-generic-eps-simulator
gnome-terminal --tab --title="FSS Sim" -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-single-simulator generic-fss-sim
gnome-terminal --tab --title='IMU Sim' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-generic-imu-simulator
gnome-terminal --tab --title='GPS Sim' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-gps-simulator
gnome-terminal --tab --title='Radio Sim' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-generic-radio-simulator
gnome-terminal --tab --title='RW Sim' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-generic-reactionwheel-simulator
gnome-terminal --tab --title='Sample Sim' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-sample-simulator
gnome-terminal --tab --title='Torquer Sim' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-generic-torquer-simulator
gnome-terminal --tab --title='42 Truth Sim' -- docker run --rm -it -v $SIM_DIR:$SIM_DIR --network=host -w $SIM_BIN nos3  $SIM_BIN/nos3-single-simulator truth42sim
echo ""

echo "COSMOS Ground Station..."
cd $BASE_DIR/gsw/cosmos
export MISSION_NAME=$(echo "NOS3")
export PROCESSOR_ENDIANNESS=$(echo "LITTLE_ENDIAN")
docker run --rm -e DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro -e QT_X11_NO_MITSHM=1 \
    -v $SCRIPT_DIR/../cosmos:/cosmos/cosmos \
    -v $SCRIPT_DIR/../../components/:/COMPONENTS -w /cosmos/cosmos -d --network=host \
    ballaerospace/cosmos /bin/bash -c 'ruby Launcher -c nos3_launcher.txt --system nos3_system.txt && true' # true is necessary to avoid setpgrp error
echo ""
sleep 5

echo "Flight Software..."
cd $FSW_BIN
#gnome-terminal --title="NOS3 Flight Software" -- docker run --rm -it --name nos-fsw -v $FSW_BIN:$FSW_BIN --network=host -w $FSW_BIN --sysctl fs.mqueue.msg_max=500 nos3 $FSW_BIN/core-cpu1 -R PO &
gnome-terminal --title="NOS3 Flight Software" -- docker run --rm -it --name nos-fsw -v $FSW_BIN:$FSW_BIN --network=host -w $FSW_BIN --sysctl fs.mqueue.msg_max=1500 nos3 sudo ./core-cpu1 -R PO &

echo ""

