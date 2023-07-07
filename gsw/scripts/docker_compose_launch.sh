#!/bin/bash -i
#
# Convenience script for NOS3 development
# Use with the Dockerfile in the deployment repository
# https://docs.docker.com/engine/install/ubuntu/
#

export SCRIPT_DIR=$(cd `dirname $0` && pwd)
export BASE_DIR=$(cd `dirname $SCRIPT_DIR`/.. && pwd)
export FSW_DIR=$BASE_DIR/fsw/build/exe/cpu1
export GSW_DIR=$BASE_DIR/gsw/cosmos
if [ -f "/etc/redhat-release" ]; then
    # https://github.com/containers/podman/issues/14284#issuecomment-1130113553
    # sudo sed -i 's/runtime = "runc"/runtime = "crun" # "runc"/g' /usr/share/containers/containers.conf 
    DFLAGS="sudo docker run --rm --group-add keep-groups -it"
    DNETWORK="sudo docker network"
else
    DFLAGS="docker run --rm -it"
    DNETWORK="docker network"
fi
export SIM_DIR=$BASE_DIR/sims/build
export SIM_BIN=$SIM_DIR/bin
export SIMS=$(cd $SIM_BIN; ls nos3*simulator)

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
    NOS3_GC
#$DFLAGS --network=SC01 --name testcon nos3 /bin/bash &
echo ""

echo "42..."
cd /opt/nos3/42/
rm -rf NOS3InOut
cp -r $BASE_DIR/sims/cfg/InOut /opt/nos3/42/NOS3InOut

#echo "COSMOS Ground Station..."
#cd $BASE_DIR/gsw/cosmos
#export MISSION_NAME=$(echo "NOS3")
#export PROCESSOR_ENDIANNESS=$(echo "LITTLE_ENDIAN")
#$DFLAGS -e DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix:ro -e QT_X11_NO_MITSHM=1 \
#    --volume $GSW_DIR:/cosmos/cosmos \
#    --volume $BASE_DIR/components:/COMPONENTS -w /cosmos/cosmos -d --name cosmos --network=NOS3_GC \
#    ballaerospace/cosmos /bin/bash -c 'ruby Launcher -c nos3_launcher.txt --system nos3_system.txt && true' # true is necessary to avoid setpgrp error

# This is probably where I will create (1) the overarching network and (2) the COSMOS 
# container. Then I will add the COSMOS container to every one of the other networks
# in the below loop. Consider naming the network sc_0 or something fairly general/
# universal.

cd $SCRIPT_DIR

export SATNUM=2
for (( i=1; i<=$SATNUM; i++ ))
do
    export PROJNAME="sc_"$i
    export NETNAME="sc_"$i"_satnet"
    echo $PROJNAME
    export FORTYTWONAME="fortytwo"$i
    export FSWNAME="nos_fsw"$i
    docker network create $NETNAME
    gnome-terminal --tab --title="42" -- $DFLAGS -e DISPLAY=$DISPLAY -v /opt/nos3/42/NOS3InOut:/opt/nos3/42/NOS3InOut \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro --name $FORTYTWONAME --network=$NETNAME --network-alias=fortytwo -w /opt/nos3/42 -t ivvitc/nos3 /opt/nos3/42/42 NOS3InOut 

    # SECTION TO CREATE A NEW COSMOS FOR EACH CONTAINER, TO SEE IF THAT IS THE PROBLEM
    export COSMOSNAME="cosmos"$i
    $DFLAGS -e DISPLAY=$DISPLAY --volume /tmp/.X11-unix:/tmp/.X11-unix:ro -e QT_X11_NO_MITSHM=1 \
        --volume $GSW_DIR:/cosmos/cosmos \
        --volume $BASE_DIR/components:/COMPONENTS -w /cosmos/cosmos -d --name $COSMOSNAME \
        --network=$NETNAME --network-alias=cosmos ballaerospace/cosmos /bin/bash -c \
        'ruby Launcher -c nos3_launcher.txt --system nos3_system.txt && true' # true is necessary to avoid setpgrp error

#    docker network connect --alias cosmos $NETNAME cosmos
    sleep 5
    gnome-terminal --title="NOS3 Flight Software" -- $DFLAGS -v $FSW_DIR:$FSW_DIR --name $FSWNAME -h nos-fsw \
    --network=$NETNAME --network-alias=nos-fsw -w $FSW_DIR --sysctl fs.mqueue.msg_max=1500 ivvitc/nos3 ./core-cpu1 -R PO &
#    sleep 5
    # The below, when uncommented, will create a number of satellites equal to $SATNUM.
    # Each one will be prefixed with the name "sc_", followed by the number of the
    # satellite in order. 
#    export RADIONAME="radio_sim"$i
#    gnome-terminal --tab --title='Radio Sim' -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name radio_sim2 --network=$NETNAME --network-alias=radio_sim -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-generic-radio-simulator
    docker-compose -p $PROJNAME up -d
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

export LASTNETNAME="sc_"$SATNUM"_satnet"
docker network connect --alias next_radio $LASTNETNAME sc_1_nos3-radio-simulator_1

#gnome-terminal --tab --title="NOS Time Driver"   -- $DFLAGS -v $SIM_DIR:$SIM_DIR --name nos_time_driver   --network=NOS3_GC -w $SIM_BIN ivvitc/nos3 $SIM_BIN/nos3-single-simulator time
#docker network connect --alias nos_time_driver sc_1_satnet nos_time_driver
#docker network connect --alias nos_time_driver sc_2_satnet nos_time_driver

