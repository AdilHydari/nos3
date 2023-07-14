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

echo "Create ground networks..."
$DNETWORK create \
    --driver=bridge \
    --subnet=192.168.41.0/24 \
    --gateway=192.168.41.1 \
    NOS3_GC
echo ""

export SATNUM=2

#
# Spacecraft Loop
#
for (( i=1; i<=$SATNUM; i++ ))
do
    export PROJNAME="sc_"$i
    export NETNAME="sc_"$i"_satnet"
    echo $NETNAME
    let j=($i+41)
    
    echo $PROJNAME " - Create spacecraft network..."
    $DNETWORK create \
        --driver=bridge \
        --subnet=192.168.$j.0/24 \
        --gateway=192.168.$j.1 \
        $NETNAME
    echo ""

    echo $PROJNAME " - 42..."
    cd /opt/nos3/42/
    rm -rf NOS3InOut
    cp -r $BASE_DIR/sims/cfg/InOut /opt/nos3/42/NOS3InOut
    xhost +local:*
    gnome-terminal --tab --title=$PROJNAME" - 42" -- $DFLAGS -e DISPLAY=$DISPLAY -v /opt/nos3/42/NOS3InOut:/opt/nos3/42/NOS3InOut -v /tmp/.X11-unix:/tmp/.X11-unix:ro --name $PROJNAME"_fortytwo" --network=$NETNAME --network-alias=fortytwo -w /opt/nos3/42 -t ivvitc/nos3 /opt/nos3/42/42 NOS3InOut
    echo ""

    echo $PROJNAME " - COSMOS Ground Station..."
    cd $BASE_DIR/gsw/cosmos
    export MISSION_NAME=$(echo "NOS3")
    export PROCESSOR_ENDIANNESS=$(echo "LITTLE_ENDIAN")
    $DFLAGS -e DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix:ro -e QT_X11_NO_MITSHM=1 \
        --volume $GSW_DIR:/cosmos/cosmos \
        --volume $BASE_DIR/components:/COMPONENTS \
        -w /cosmos/cosmos -d --name $PROJNAME"_cosmos" -h $PROJNAME"_cosmos" --network-alias=cosmos --network=$NETNAME \
        ballaerospace/cosmos /bin/bash -c 'ruby Launcher -c nos3_launcher.txt --system nos3_system.txt && true' # true is necessary to avoid setpgrp error

    echo $PROJNAME " - Flight Software..."
    cd $FSW_DIR
    gnome-terminal --title=$PROJNAME" - NOS3 Flight Software" -- $DFLAGS -v $FSW_DIR:$FSW_DIR --name $PROJNAME"_nos_fsw" -h nos_fsw --network=$NETNAME -w $FSW_DIR --sysctl fs.mqueue.msg_max=1500 ivvitc/nos3 ./core-cpu1 -R PO &
    echo ""

    echo $PROJNAME " - Simulators..."
    cd $SIM_BIN
    gnome-terminal --tab --title=$PROJNAME" - NOS Engine Server" -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_nos3_engine_server"  -h nos_engine_server --network=$NETNAME --network-alias=$PROJNAME_nos_engine_server -w $SIM_BIN ivvitc/nos3 /usr/bin/nos_engine_server_standalone -f $SIM_BIN/nos_engine_server_config.json
    gnome-terminal --tab --title=$PROJNAME" - NOS Terminal"      -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_nos_terminal"        --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator stdio-terminal
    gnome-terminal --tab --title=$PROJNAME" - NOS UDP Terminal"  -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_nos_udp_terminal"    --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator udp-terminal
    gnome-terminal --tab --title=$PROJNAME" - 42 Truth Sim"      -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_truth42sim"          -h truth42sim --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator truth42sim
    gnome-terminal --tab --title=$PROJNAME" - CAM Sim"           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_cam_sim"             --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-cam-simulator
    gnome-terminal --tab --title=$PROJNAME" - CSS Sim"           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_css_sim"             --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-css-simulator
    gnome-terminal --tab --title=$PROJNAME" - EPS Sim"           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_eps_sim"             --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-eps-simulator
    gnome-terminal --tab --title=$PROJNAME" - FSS Sim"           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_fss_sim"             --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator generic-fss-sim
    gnome-terminal --tab --title=$PROJNAME" - IMU Sim"           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_imu_sim"             --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-imu-simulator
    gnome-terminal --tab --title=$PROJNAME" - GPS Sim"           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_gps_sim"             --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-gps-simulator
    gnome-terminal --tab --title=$PROJNAME" - RW Sim"            -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_rw_sim"              --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-reactionwheel-simulator
    gnome-terminal --tab --title=$PROJNAME" - Radio Sim"         -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_radio_sim"           -h radio_sim --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-radio-simulator
    gnome-terminal --tab --title=$PROJNAME" - Sample Sim"        -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_sample_sim"          --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-sample-simulator
    gnome-terminal --tab --title=$PROJNAME" - Torquer Sim"       -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name $PROJNAME"_torquer_sim"         --network=$NETNAME -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-torquer-simulator
    echo ""

    #if [ $i -ge 2 ]; then
    #    let j=($i-1)
    #    # The below defines the radio container name and the previous network
    #    # name; then, the current radio is connected to the previous network under
    #    # the alias "next_radio". 
    #    export RADNAME="sc_"$i"_nos3-radio-simulator_1"
    #    export PRENETNAME="sc_"$j"_satnet"
    #    echo $PRENETNAME
    #    docker network connect --alias next_radio $PRENETNAME $RADNAME
    #fi
done


echo "NOS Time Driver..."
sleep 5
gnome-terminal --tab --title="NOS Time Driver"   -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_time_driver --network=NOS3_GC -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator time
sleep 1
for (( i=1; i<=$SATNUM; i++ ))
do
    export PROJNAME="sc_"$i
    export NETNAME=$PROJNAME"_satnet"
    export TIMENAME=$PROJNAME"_nos_time_driver"
    docker network connect --alias $TIMENAME $NETNAME nos_time_driver
done
echo ""

#docker network connect --alias next_radio "sc_"$SATNUM"_satnet" sc_1_nos3-radio-simulator_1

echo "Docker launch script completed!"
