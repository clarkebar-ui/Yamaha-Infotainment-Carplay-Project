#!/bin/sh 

_NAV_DIR_=/fs/mmc0/nav
_NDR_SAVE_DIR_=/fs/mmc0/persistency
# Marker file for HU mounting angle LCF
HU_ANGLE_LCF_FILE=/fs/etfs/NavigationAngle.txt
# HU mounting angle LCF value
HU_ANGLE_LCF=""

# Check for serial port
if [ ! -e /dev/ser2 ]; then
  echo "Serial driver not loaded exiting"
  exit 1
fi

if [ ! -d $_NDR_SAVE_DIR_ ]; then
  mkdir $_NDR_SAVE_DIR_
fi

# Send the configuration commands to enable $PSTMPRES NMEA sentence 
echo  "\$PSTMSETPAR,1200,220000,2\r\n\$PSTMSAVEPAR\r\n" > /dev/ser2	
# echo "flexgps_ndr: Disabling GLONASS constellation for positioning"

# Setup Replay option if marker present
NDR_OPTION="-DisableServerSocket"
if [ -e /fs/etfs/REPLAY_ENABLED ]; then
   export LD_LIBRARY_PATH=$_NAV_DIR_/tools/ReplayManager/:$LD_LIBRARY_PATH
   $_NAV_DIR_/scripts/replayManager.sh
	NDR_OPTION="-SensorReplay"
	echo "flexgps_ndr:ndr configured for sensor replay"
fi

# Start GPS driver
cd $_NAV_DIR_/pos/
nice -n -1 $_NAV_DIR_/pos/vdev-flexgps -d/hbsystem/multicore/navi/g -b115200 -c/dev/ser2 -n -E -x$_NAV_DIR_/scripts/restartGPS.sh &


# Get the LCF value from marker file
if [ -e $HU_ANGLE_LCF_FILE ]; then
	HU_ANGLE_LCF=`cat $HU_ANGLE_LCF_FILE`
	echo "HU mounting angle in LCF file" $HU_ANGLE_LCF_FILE "is: " $HU_ANGLE_LCF
else
   echo "LCF file for HU mounting angle" $HU_ANGLE_LCF_FILE "does not exist, using the default value 0.0"
   HU_ANGLE_LCF="0.0"
fi

if [ -e /fs/etfs/LOGGING ]; then
   echo NDR Logging enabled with debug level 3
   NDR_OPTION=$NDR_OPTION" -d=3"
else
   echo NDR Logging is set to default
fi

if [ -e $_NDR_SAVE_DIR_/CVALUE0002021b.CVA ]; then
   echo CVALUE0002021b.CVA file is already present
else
   cp $_NAV_DIR_/pos/CVALUE0002021b.CVA $_NDR_SAVE_DIR_/
fi

# Start NDR and related binaries
$_NAV_DIR_/pos/ndr -e=disChina -e=DR -ch5=/dev/ipc/ch5 -hfs=$_NAV_DIR_/pos/hfs.cfg $NDR_OPTION -gyrotilt=$HU_ANGLE_LCF -SavePath=$_NDR_SAVE_DIR_ &

echo Waiting for /dev/navi/Navigation/CalibrationLevel...
waitfor /dev/navi/Navigation/CalibrationLevel
$_NAV_DIR_/pos/NDRToJSON -sigOff -path=$_NDR_SAVE_DIR_ &
