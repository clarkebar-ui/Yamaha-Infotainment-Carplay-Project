#!/bin/sh

export NNG_CRASHDUMP_FILE=/hbsystem/multicore/navi/3

_NAV_DIR_=/fs/mmc0/nav

export LD_LIBRARY_PATH=$_NAV_DIR_/lib/:$LD_LIBRARY_PATH

cd $_NAV_DIR_/update

$_NAV_DIR_/update/Synctool 1> /fs/mmc0/persistency/synctool1.log 2> /fs/mmc0/persistency/synctool2.log &

$_NAV_DIR_/update/NavUpdateController 1> /fs/mmc0/persistency/navupdatectrl1.log 2> /fs/mmc0/persistency/navupdatectrl2.log &