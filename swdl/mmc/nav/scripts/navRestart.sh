#!/bin/sh 

_NAV_DIR_=/fs/mmc0/nav
slay -skill NaviServer 
slay -skill YamahaOpenNavController 

$_NAV_DIR_/scripts/nav.sh
