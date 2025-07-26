#!/bin/sh 

_NAV_DIR_=/fs/mmc0/nav
#Speech libraries directory
_SPEECH_LIB_DIR_=/fs/etfs/speech/lib
# Navigation Engine folder
NAV_PROG_DIR=$_NAV_DIR_/engine

# Reconfigure nav to only use GPS and enable Debug.
if [[ -e /fs/etfs/GPS_ONLY ]]; then
	#if gps string not found then only write to file
	if ! grep -q "gps" $NAV_PROG_DIR/sys.txt; then
	echo "\n[gps]\nsource=\"qnx_gps\"" >> $NAV_PROG_DIR/sys.txt
	fi	
fi

if [ -e /fs/etfs/LOGGING ]; then
	#if debug string not found then only write to file
	if ! grep -q "debug" $NAV_PROG_DIR/sys.txt;then
	DEBUGCONFIG="\n[debug]\nlog_1=\"/hbsystem/multicore/navi/3,async::3\"\n[opennav]\nserver_logging=\"/hbsystem/multicore/navi/4\"\nserver_log_open_once=1\nndr_log_mapmatch=1"
	echo $DEBUGCONFIG >> $NAV_PROG_DIR/sys.txt
	fi
fi

if [ -e /fs/etfs/REPLAY_ENABLED ]; then
   export LD_LIBRARY_PATH=$_NAV_DIR_/tools/ReplayManager/:$LD_LIBRARY_PATH
   $_NAV_DIR_/scripts/replayManager.sh
fi

# Set the library path
export LD_LIBRARY_PATH=$_NAV_DIR_/lib/:$LD_LIBRARY_PATH:$_SPEECH_LIB_DIR_

# Navigation specific exports
export CFG_NAVCORE_QNX_AUDIO_CARD=-1
export CFG_NAVCORE_QNX_AUDIO_DEVICE=0
export NNG_CRASHDUMP_FILE="/hbsystem/multicore/navi/3"

# Memory manager configuration
export NNG_MAXIMUM_MEMORY=68157440

export CFG_NAVCORE_TMC_SOURCE="XM"
export CFG_NAVCORE_TMC_DEBUG=1

echo Waiting for /dev/ndr...
waitfor /dev/ndr

cd $NAV_PROG_DIR/
LD_PRELOAD=$_NAV_DIR_/lib/libopennavtmc.so $NAV_PROG_DIR/NaviServer 1> /tmp/nav1.log 2> /tmp/nav2.log &

cd $_NAV_DIR_/ON
$_NAV_DIR_/ON/YamahaOpenNavController --nobreak --disable-watchdog --bp --tp=$_NAV_DIR_/ON/onipc.hbtc &

