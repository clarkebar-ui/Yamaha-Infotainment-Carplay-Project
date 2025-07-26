#!/bin/sh

_NAV_DIR_=/fs/mmc0/nav

$_NAV_DIR_/scripts/slayer.sh
$_NAV_DIR_/scripts/flexgps_ndr.sh
$_NAV_DIR_/scripts/navRestart.sh
