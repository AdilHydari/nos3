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

echo "Create docker networks..."
$DNETWORK create \
    --driver=bridge \
    --subnet=192.168.41.0/24 \
    --gateway=192.168.41.1 \
    NOS3_GC
#$DFLAGS --network=sc_1_satnet --name testcon nos3 /bin/bash &
$DNETWORK create \
    --driver=bridge \
    --subnet=192.168.42.0/24 \
    --gateway=192.168.42.1 \
    sc_1_satnet
#$DFLAGS --network=sc_1_satnet --name testcon nos3 /bin/bash &
$DNETWORK create \
    --driver=bridge \
    --subnet=192.168.43.0/24 \
    --gateway=192.168.43.1 \
    sc_2_satnet
#$DFLAGS --network=sc_1_satnet --name testcon nos3 /bin/bash &
echo ""

echo "42..."
cd /opt/nos3/42/
rm -rf NOS3InOut
cp -r $BASE_DIR/sims/cfg/InOut /opt/nos3/42/NOS3InOut
xhost +local:*
gnome-terminal --tab --title="42" -- $DFLAGS -e DISPLAY=$DISPLAY -v /opt/nos3/42/NOS3InOut:/opt/nos3/42/NOS3InOut -v /tmp/.X11-unix:/tmp/.X11-unix:ro --name fortytwo1 --network=sc_1_satnet --network-alias=fortytwo -w /opt/nos3/42 -t ivvitc/nos3 /opt/nos3/42/42 NOS3InOut
gnome-terminal --tab --title="42" -- $DFLAGS -e DISPLAY=$DISPLAY -v /opt/nos3/42/NOS3InOut:/opt/nos3/42/NOS3InOut -v /tmp/.X11-unix:/tmp/.X11-unix:ro --name fortytwo2 --network=sc_2_satnet --network-alias=fortytwo -w /opt/nos3/42 -t ivvitc/nos3 /opt/nos3/42/42 NOS3InOut
echo ""

echo "COSMOS Ground Station..."
cd $BASE_DIR/gsw/cosmos
export MISSION_NAME=$(echo "NOS3")
export PROCESSOR_ENDIANNESS=$(echo "LITTLE_ENDIAN")
#$DFLAGS -e DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix:ro -e QT_X11_NO_MITSHM=1 \
#    --volume $GSW_DIR:/cosmos/cosmos \
#    --volume $BASE_DIR/components:/COMPONENTS -w /cosmos/cosmos -d --name cosmos_gc --network=NOS3_GC \
#    ballaerospace/cosmos /bin/bash -c 'ruby Launcher -c nos3_launcher.txt --system nos3_system.txt && true' # true is necessary to avoid setpgrp error
#docker network connect --alias cosmos sc_1_satnet cosmos_gc
#$DFLAGS -e DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix:ro -e QT_X11_NO_MITSHM=1 \
#    --volume $GSW_DIR:/cosmos/cosmos \
#    --volume $BASE_DIR/components:/COMPONENTS -w /cosmos/cosmos -d --name cosmos_gc2 --network=NOS3_GC \
#    ballaerospace/cosmos /bin/bash -c 'ruby Launcher -c nos3_launcher.txt --system nos3_system.txt && true' # true is necessary to avoid setpgrp error
#docker network connect --alias cosmos sc_2_satnet cosmos_gc2
$DFLAGS -e DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix:ro -e QT_X11_NO_MITSHM=1 \
    --volume $GSW_DIR:/cosmos/cosmos \
    --volume $BASE_DIR/components:/COMPONENTS -w /cosmos/cosmos -d --name cosmos_1 --network=sc_1_satnet --network-alias=cosmos \
    ballaerospace/cosmos /bin/bash -c 'ruby Launcher -c nos3_launcher.txt --system nos3_system.txt && true' # true is necessary to avoid setpgrp error

#$DFLAGS -e DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix:ro -e QT_X11_NO_MITSHM=1 \
#    --volume $GSW_DIR:/cosmos/cosmos \
#    --volume $BASE_DIR/components:/COMPONENTS -w /cosmos/cosmos -d --name cosmos_2 --network=sc_2_satnet --network-alias=cosmos \
#    ballaerospace/cosmos /bin/bash -c 'ruby Launcher -c nos3_launcher.txt --system nos3_system.txt && true' # true is necessary to avoid setpgrp error

#gnome-terminal --tab --title="NOS Time Driver"   -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_time_driver --network=NOS3_GC -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator time


echo ""

export SATNUM=2
for (( i=1; i<=$SATNUM; i++ ))
do
    export PROJNAME="sc_"$i
    export NETNAME="sc_"$i"_satnet"

    echo "Flight Software..."
    cd $FSW_DIR
    gnome-terminal --title="NOS3 Flight Software" -- $DFLAGS -v $FSW_DIR:$FSW_DIR --name "nos-fsw"$i -h nos-fsw --network=$NETNAME --network-alias=nos-fsw -w $FSW_DIR --sysctl fs.mqueue.msg_max=1500 ivvitc/nos3 ./core-cpu1 -R PO &
   
    echo ""

    echo "Simulators..."
    cd $SIM_BIN
    gnome-terminal --tab --title="NOS Engine Server" -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "nos_engine_server"$i -h nos_engine_server --network=$NETNAME --network-alias=nos_engine_server -w $SIM_BIN ivvitc/nos3 /usr/bin/nos_engine_server_standalone -f $SIM_BIN/nos_engine_server_config.json
    gnome-terminal --tab --title='42 Truth Sim'      -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "truth42sim"$i        --network=$NETNAME --network-alias=truth42sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator truth42sim
    gnome-terminal --tab --title='CAM Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "cam_sim"$i           --network=$NETNAME --network-alias=cam_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-cam-simulator
    gnome-terminal --tab --title='CSS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "css_sim"$i           --network=$NETNAME --network-alias=css_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-css-simulator
    gnome-terminal --tab --title='EPS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "eps_sim"$i           --network=$NETNAME --network-alias=eps_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-eps-simulator
    gnome-terminal --tab --title="FSS Sim"           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "fss_sim"$i           --network=$NETNAME --network-alias=fss_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator generic-fss-sim
    gnome-terminal --tab --title='IMU Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "imu_sim"$i           --network=$NETNAME --network-alias=imu_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-imu-simulator
    gnome-terminal --tab --title='GPS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "gps_sim"$i           --network=$NETNAME --network-alias=gps_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-gps-simulator
    gnome-terminal --tab --title='RW Sim'            -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "rw_sim"$i            --network=$NETNAME --network-alias=rw_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-reactionwheel-simulator
    gnome-terminal --tab --title='Radio Sim'         -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "sc_"$i"_nos3-radio-simulator_1"         --network=$NETNAME --network-alias=radio_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-radio-simulator
    gnome-terminal --tab --title='Sample Sim'        -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "sample_sim"$i        --network=$NETNAME --network-alias=sample_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-sample-simulator
    gnome-terminal --tab --title='Torquer Sim'       -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "torquer_sim"$i       --network=$NETNAME --network-alias=torquer_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-torquer-simulator
    gnome-terminal --tab --title='NOS Terminal'      -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "nos_terminal"$i      --network=$NETNAME --network-alias=nos_terminal -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator stdio-terminal
    gnome-terminal --tab --title='NOS UDP Terminal'  -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "nos_udp_terminal"$i  --network=$NETNAME --network-alias=nos_udp_terminal -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator udp-terminal

#    sleep 5
#    gnome-terminal --tab --title="NOS Time Driver"   -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name "nos_time_driver"$i   --network=$NETNAME --network-alias=nos_time_driver -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator time
#    docker network connect --alias nos_time_driver $NETNAME nos_time_driver

    if [ $i -ge 2 ]; then
        let j=($i-1)
        # The below defines the radio container name and the previous network
        # name; then, the current radio is connected to the previous network under
        # the alias "next_radio". 
        export RADNAME="sc_"$i"_nos3-radio-simulator_1"
        export PRENETNAME="sc_"$j"_satnet"
        docker network connect --alias next_radio $PRENETNAME $RADNAME
    fi

done

sleep 5
gnome-terminal --tab --title="NOS Time Driver"   -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_time_driver --network=NOS3_GC -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator time
sleep 1
docker network connect --alias nos_time_driver sc_1_satnet nos_time_driver
docker network connect --alias nos_time_driver sc_2_satnet nos_time_driver


docker network connect --alias next_radio "sc_"$SATNUM"_satnet" radio_sim1

#sleep 5
#gnome-terminal --tab --title="NOS Time Driver"   -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_time_driver --network=NOS3_GC -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator time
#docker network connect --alias nos_time_driver "sc_1_satnet" nos_time_driver
#docker network connect --alias nos_time_driver "sc_2_satnet" nos_time_driver


#echo "Flight Software..."
#cd $FSW_DIR
#gnome-terminal --title="NOS3 Flight Software" -- $DFLAGS -v $FSW_DIR:$FSW_DIR --name nos-fsw1 -h nos-fsw --network=sc_1_satnet --network-alias=nos-fsw -w $FSW_DIR --sysctl fs.mqueue.msg_max=1500 ivvitc/nos3 ./core-cpu1 -R PO &
#gnome-terminal --title="NOS3 Flight Software" -- $DFLAGS -v $FSW_DIR:$FSW_DIR --name nos-fsw2 -h nos-fsw --network=sc_2_satnet --network-alias=nos-fsw -w $FSW_DIR --sysctl fs.mqueue.msg_max=1500 ivvitc/nos3 ./core-cpu1 -R PO &
# Note: Can keep open if desired after a new gnome-profile is manually created
#gnome-terminal --title="NOS3 Flight Software" --window-with-profile=KeepOpen -- $DFLAGS -v $FSW_DIR:$FSW_DIR --name nos-fsw -h nos-fsw --network=sc_1_satnet -w $FSW_DIR --sysctl fs.mqueue.msg_max=1500 ivvitc/nos3 ./core-cpu1 -R PO &
#echo ""
#
#echo "Simulators..."
#cd $SIM_BIN
#gnome-terminal --tab --title="NOS Engine Server" -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_engine_server1 -h nos_engine_server --network=sc_1_satnet --network-alias=nos_engine_server -w $SIM_BIN ivvitc/nos3 /usr/bin/nos_engine_server_standalone -f $SIM_BIN/nos_engine_server_config.json
#gnome-terminal --tab --title='42 Truth Sim'      -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name truth42sim1        --network=sc_1_satnet --network-alias=truth42sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator truth42sim
#gnome-terminal --tab --title='CAM Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name cam_sim1           --network=sc_1_satnet --network-alias=cam_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-cam-simulator
#gnome-terminal --tab --title='CSS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name css_sim1           --network=sc_1_satnet --network-alias=css_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-css-simulator
#gnome-terminal --tab --title='EPS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name eps_sim1           --network=sc_1_satnet --network-alias=eps_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-eps-simulator
#gnome-terminal --tab --title="FSS Sim"           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name fss_sim1           --network=sc_1_satnet --network-alias=fss_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator generic-fss-sim
#gnome-terminal --tab --title='IMU Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name imu_sim1           --network=sc_1_satnet --network-alias=imu_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-imu-simulator
#gnome-terminal --tab --title='GPS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name gps_sim1           --network=sc_1_satnet --network-alias=gps_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-gps-simulator
#gnome-terminal --tab --title='RW Sim'            -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name rw_sim1            --network=sc_1_satnet --network-alias=rw_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-reactionwheel-simulator
#gnome-terminal --tab --title='Radio Sim'         -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name radio_sim1         --network=sc_1_satnet --network-alias=radio_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-radio-simulator
#gnome-terminal --tab --title='Sample Sim'        -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name sample_sim1        --network=sc_1_satnet --network-alias=sample_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-sample-simulator
#gnome-terminal --tab --title='Torquer Sim'       -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name torquer_sim1       --network=sc_1_satnet --network-alias=torquer_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-torquer-simulator
#gnome-terminal --tab --title='NOS Terminal'      -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_terminal1      --network=sc_1_satnet --network-alias=nos_terminal -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator stdio-terminal
#gnome-terminal --tab --title='NOS UDP Terminal'  -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_udp_terminal1  --network=sc_1_satnet --network-alias=nos_udp_terminal -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator udp-terminal
#docker network connect --alias next_radio sc_2_satnet radio_sim1
#
#
#gnome-terminal --tab --title="NOS Engine Server" -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_engine_server2 -h nos_engine_server --network=sc_2_satnet --network-alias=nos_engine_server -w $SIM_BIN ivvitc/nos3 /usr/bin/nos_engine_server_standalone -f $SIM_BIN/nos_engine_server_config.json
#gnome-terminal --tab --title='42 Truth Sim'      -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name truth42sim2        --network=sc_2_satnet --network-alias=truth42sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator truth42sim
#gnome-terminal --tab --title='CAM Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name cam_sim2           --network=sc_2_satnet --network-alias=cam_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-cam-simulator
#gnome-terminal --tab --title='CSS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name css_sim2           --network=sc_2_satnet --network-alias=css_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-css-simulator
#gnome-terminal --tab --title='EPS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name eps_sim2           --network=sc_2_satnet --network-alias=eps_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-eps-simulator
#gnome-terminal --tab --title="FSS Sim"           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name fss_sim2           --network=sc_2_satnet --network-alias=fss_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator generic-fss-sim
#gnome-terminal --tab --title='IMU Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name imu_sim2           --network=sc_2_satnet --network-alias=imu_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-imu-simulator
#gnome-terminal --tab --title='GPS Sim'           -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name gps_sim2           --network=sc_2_satnet --network-alias=gps_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-gps-simulator
#gnome-terminal --tab --title='RW Sim'            -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name rw_sim2            --network=sc_2_satnet --network-alias=rw_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-reactionwheel-simulator
#gnome-terminal --tab --title='Radio Sim'         -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name radio_sim2         --network=sc_2_satnet --network-alias=radio_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-radio-simulator
#gnome-terminal --tab --title='Sample Sim'        -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name sample_sim2        --network=sc_2_satnet --network-alias=sample_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-sample-simulator
#gnome-terminal --tab --title='Torquer Sim'       -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name torquer_sim2       --network=sc_2_satnet --network-alias=torquer_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-torquer-simulator
#gnome-terminal --tab --title='NOS Terminal'      -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_terminal2      --network=sc_2_satnet --network-alias=nos_terminal -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator stdio-terminal
#gnome-terminal --tab --title='NOS UDP Terminal'  -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_udp_terminal2  --network=sc_2_satnet --network-alias=nos_udp_terminal -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator udp-terminal
#
#docker network connect --alias next_radio sc_1_satnet radio_sim2
#
#sleep 5
#gnome-terminal --tab --title="NOS Time Driver"   -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_time_driver1 --network=sc_1_satnet --network-alias=nos_time_driver -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator time
#gnome-terminal --tab --title="NOS Time Driver"   -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_time_driver2 --network=sc_2_satnet --network-alias=nos_time_driver -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator time

#gnome-terminal --tab --title="NOS Time Driver"   -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_time_driver_gc --network=NOS3_GC -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator time
#docker network connect --alias nos_time_driver sc_1_satnet nos_time_driver_gc
#docker network connect --alias nos_time_driver sc_2_satnet nos_time_driver_gc
echo ""

