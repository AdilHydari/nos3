#!/bin/bash -i
#
# Convenience script for NOS3 development
#

SCRIPT_DIR=$(cd `dirname $0` && pwd)
BASE_DIR=$(cd `dirname $SCRIPT_DIR`/.. && pwd)
FSW_BIN=$BASE_DIR/fsw/build/exe/cpu1
SIM_BIN=$BASE_DIR/sims/build/bin
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

echo "Make data folders..."
# FSW Side
mkdir $FSW_BIN/data 2> /dev/null
mkdir $FSW_BIN/data/cam 2> /dev/null
mkdir $FSW_BIN/data/evs 2> /dev/null
mkdir $FSW_BIN/data/hk 2> /dev/null
mkdir $FSW_BIN/data/inst 2> /dev/null
# GSW Side
mkdir /tmp/data 2> /dev/null
mkdir /tmp/data/cam 2> /dev/null
mkdir /tmp/data/evs 2> /dev/null
mkdir /tmp/data/hk 2> /dev/null
mkdir /tmp/data/inst 2> /dev/null
mkdir /tmp/uplink 2> /dev/null
cp $BASE_DIR/fsw/build/exe/cpu1/cf/cfe_es_startup.scr /tmp/uplink/tmp0.so 2> /dev/null
cp $BASE_DIR/fsw/build/exe/cpu1/cf/sample.so /tmp/uplink/tmp1.so 2> /dev/null

echo "42..."
cd /opt/nos3/42/
rm -rf NOS3InOut
cp -r $BASE_DIR/sims/cfg/InOut /opt/nos3/42/NOS3InOut
gnome-terminal --tab --title="42 Dynamic Simulator" -- /opt/nos3/42/42 NOS3InOut

echo "Simulators..."
cd $SIM_BIN
gnome-terminal --tab --title="NOS Engine Server" -- /usr/bin/nos_engine_server_standalone -f $SIM_BIN/nos_engine_server_config.json
#gnome-terminal --tab --title="NOS Time Driver" -- $SIM_BIN/nos3-single-simulator time
gnome-terminal --tab --title="NOS Terminal" -- $SIM_BIN/nos3-single-simulator terminal
gnome-terminal --tab --title='CAM Sim' -- $SIM_BIN/nos3-cam-simulator
gnome-terminal --tab --title='CSS Sim' -- $SIM_BIN/nos3-generic-css-simulator
gnome-terminal --tab --title='EPS Sim' -- $SIM_BIN/nos3-generic-eps-simulator
gnome-terminal --tab --title="FSS Sim" -- $SIM_BIN/nos3-single-simulator generic-fss-sim
gnome-terminal --tab --title='GPS Sim' -- $SIM_BIN/nos3-gps-simulator
gnome-terminal --tab --title='Radio Sim' -- $SIM_BIN/nos3-generic-radio-simulator
gnome-terminal --tab --title='RW Sim' -- $SIM_BIN/nos3-generic-reactionwheel-simulator
gnome-terminal --tab --title='Sample Sim' -- $SIM_BIN/nos3-sample-simulator
gnome-terminal --tab --title='Torquer Sim' -- $SIM_BIN/nos3-generic-torquer-simulator
gnome-terminal --tab --title="42 Truth Sim" -- $SIM_BIN/nos3-single-simulator truth42sim

echo "COSMOS Ground Station..."
cd $BASE_DIR/gsw/cosmos
export MISSION_NAME=$(echo "NOS3")
export PROCESSOR_ENDIANNESS=$(echo "LITTLE_ENDIAN")
ruby Launcher -c nos3_launcher.txt --system nos3_system.txt &

sleep 5

echo "Flight Software..."
cd $FSW_BIN
gnome-terminal --title="NOS3 Flight Software" -- $FSW_BIN/core-cpu1 -R PO &

# Note: Can keep open if desired after a new gnome-profile is manually created
#gnome-terminal --window-with-profile=KeepOpen --title="NOS3 Flight Software" -- $FSW_BIN/core-cpu1 -R PO &
