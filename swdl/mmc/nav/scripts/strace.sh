#!/bin/sh

_ROOT_PATH_=/fs/mmc0
_TIMESTAMP_=`date "+%y%m%d_%H%M%S"`
_KEV_FILESIZE_=50M
_TOP_ITERATIONS_=5
_PRODUCT_INFO_FILE_=/etc/system/config/productinfo.conf
_KEV_TMP_LOCATION_=/dev/shmem/tracebuffer.kev

if [ -n "$1" ]; then
    _ROOT_PATH_="$1";
fi

_OUTPUT_FOLDER_PATH_=$_ROOT_PATH_/STrace_$_TIMESTAMP_
mkdir -p $_OUTPUT_FOLDER_PATH_

echo "***** Started STrace " $_OUTPUT_FOLDER_PATH_ "*****"
echo "***** Contact: Shanmukha *****"

echo "Tracing kernel events..."
tracelogger -M -S$_KEV_FILESIZE_ -n0 -w &
echo "Sleeping for 10s"
sleep 10
echo "Killing tracelogger"
slay -f tracelogger

echo "Copying kev file from temporary location to output folder"
cp -f $_KEV_TMP_LOCATION_ $_OUTPUT_FOLDER_PATH_/

echo "Removing kev file from temporary location"
rm -f $_KEV_TMP_LOCATION_

echo "Copying product info"
cp  $_PRODUCT_INFO_FILE_ $_OUTPUT_FOLDER_PATH_/

echo "Logging system info"
pidin info > $_OUTPUT_FOLDER_PATH_/pidin_info.log

echo "Logging process list"
pidin a  > $_OUTPUT_FOLDER_PATH_/process_list.log

echo "Logging threads states"
pidin > $_OUTPUT_FOLDER_PATH_/threads.log

echo "Logging memory info"
showmem -P -S > $_OUTPUT_FOLDER_PATH_/memory.log

echo "Logging service list"
ls /dev/serv-mon/ > $_OUTPUT_FOLDER_PATH_/services.log

echo "Logging /dev/ipc statistics"
cat /dev/ipc/debug > $_OUTPUT_FOLDER_PATH_/ipc_stats.log

echo "Logging disk usage"
df > $_OUTPUT_FOLDER_PATH_/disk_usage.log

echo "Saving system logs"
sloginfo > $_OUTPUT_FOLDER_PATH_/sloginfo.log

echo "Taking screen shot"
screenshot -filename=$_OUTPUT_FOLDER_PATH_/screenshot.bmp

echo "Logging system usage(top)"
top -d -i $_TOP_ITERATIONS_ > $_OUTPUT_FOLDER_PATH_/top.log

echo  "Logging core files list"
find / -type f -name *.core > $_OUTPUT_FOLDER_PATH_/corefiles.log

echo "Copying core files if exists"
while read filename ; do cp "$filename" $_OUTPUT_FOLDER_PATH_/ ; done < $_OUTPUT_FOLDER_PATH_/corefiles.log

echo "Removing core files"
while read filename ; do rm -rf "$filename" ; done < $_OUTPUT_FOLDER_PATH_/corefiles.log

echo "***** Finished STrace " $_OUTPUT_FOLDER_PATH_ "*****"

dbus-send /com/harman/service/Utility com.harman.ServiceIpc.Emit \
string:'STraceFinished' \
string:'{"folderPath":"'$_OUTPUT_FOLDER_PATH_'"}'
