#!/bin/sh 

_NAV_DIR_=/fs/mmc0/nav
#
# Script to restart the FlexGPS driver.
# This is called by vdev-flexgps itself if there is no data received from the serial port for 15 seconds
#

# First kill the FlexGPS driver
echo "*** Killing vdev-flexgps ***"
slay -skill vdev-flexgps
sleep 3
	
# Now reset the GPS chip
echo 1 > /dev/gpio/GPS_RESET
sleep 1
echo 0 > /dev/gpio/GPS_RESET
# Wait for some time, at least 3 sec because the POR of GPS chip will take about 3 seconds
sleep 3

# Check for serial port
if [ ! -e /dev/ser2 ]; then
  echo "Serial driver not loaded exiting"
  exit 1
fi

# Start GPS driver
cd $_NAV_DIR_/pos/
$_NAV_DIR_/pos/vdev-flexgps -d/hbsystem/multicore/navi/g -b115200 -c/dev/ser2 -n -E -x$_NAV_DIR_/scripts/restartGPS.sh &
