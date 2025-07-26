#!/bin/sh

_NAV_DIR_=/fs/mmc0/nav

_NAV_USB_DIR_=/fs/usb0/nng

if [ ! -d $_NAV_USB_DIR_ ]; then
   echo "##### ERROR: /fs/usb0/nng is not present #####"
   exit 1
fi

echo "***** Killing NaviServer *****"
slay -skill NaviServer
sleep 2

echo "***** Deleting NNG engine binaries *****"
echo "Deleting NaviServer"
rm $_NAV_DIR_/engine/NaviServer
echo "Deleting data.zip"
rm $_NAV_DIR_/engine/data.zip
echo "Deleting sys.txt"
rm $_NAV_DIR_/engine/sys.txt
echo "Deleting tahoma.ttf"
rm $_NAV_DIR_/engine/tahoma.ttf
echo "Deleting tahomabd.ttf"
rm $_NAV_DIR_/engine/tahomabd.ttf
echo "Deleting ux/"
rm -r $_NAV_DIR_/engine/ux/
echo "Deleting content/car/"
rm -r $_NAV_DIR_/engine/content/car/
echo "Deleting content/skin/"
rm -r $_NAV_DIR_/engine/content/skin/

echo "***** Copying NNG engine binaries *****"
echo "Copying NaviServer"
cp $_NAV_USB_DIR_/NaviServer $_NAV_DIR_/engine/

echo "Copying data.zip"
cp $_NAV_USB_DIR_/data.zip $_NAV_DIR_/engine/

echo "Copying sys.txt"
cp $_NAV_USB_DIR_/sys.txt $_NAV_DIR_/engine/

echo "Copying tahoma.ttf"
cp $_NAV_USB_DIR_/tahoma.ttf $_NAV_DIR_/engine/

echo "Copying tahomabd.ttf"
cp $_NAV_USB_DIR_/tahomabd.ttf $_NAV_DIR_/engine/

echo "Copying ux/"
cp -r $_NAV_USB_DIR_/ux/ $_NAV_DIR_/engine/

echo "Copying content/"
cp -r $_NAV_USB_DIR_/content/ $_NAV_DIR_/engine/

echo "Done copying, Please restart the target device"
