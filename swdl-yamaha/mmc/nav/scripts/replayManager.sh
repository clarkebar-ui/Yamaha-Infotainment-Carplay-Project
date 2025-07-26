#!/bin/sh

_NAV_DIR_=/fs/mmc0/nav
_NDR_SAVE_DIR_=/fs/mmc0/persistency

if [ ! -e $_NDR_SAVE_DIR_/DeadReckoning_Calibration.bin ]; then
   echo "##### ERROR: /fs/etfs/usr/var/DeadReckoning_Calibration.bin is not present creating dummy file #####"
   touch $_NDR_SAVE_DIR_/DeadReckoning_Calibration.bin
fi

var=$(pidin a | grep ReplayManager | grep -v grep)
if [ -n "$var" ]; then
   echo "\n#### ReplayManager already running ####\n"
   exit 1
fi

export LD_LIBRARY_PATH=$_NAV_DIR_/tools/ReplayManager/:$_NAV_DIR_/pos/:$LD_LIBRARY_PATH

cd $_NAV_DIR_/tools/ReplayManager/

ln -sP $_NAV_DIR_/tools/ReplayManager/ReplayConfig.txt $_NAV_DIR_/engine/ReplayConfig.txt
ln -sP $_NAV_DIR_/tools/ReplayManager/ReplayConfig.txt $_NAV_DIR_/pos/ReplayConfig.txt

$_NAV_DIR_/tools/ReplayManager/ReplayManager &

