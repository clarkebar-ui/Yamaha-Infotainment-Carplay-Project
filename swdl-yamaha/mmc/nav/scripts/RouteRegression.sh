#!/bin/sh

echo "Started RouteRegression"

_BIN_DIR_=/fs/mmc0/nav/tools/RouteRegression
_OUTPUT_DIR_=/fs/mmc0/nav/tools/RouteRegression/output

mkdir $_OUTPUT_DIR_

dbus-send --print-reply --type=method_call \
--dest='com.harman.service.Navigation' /com/harman/service/Navigation \
com.harman.ServiceIpc.Invoke \
string:'JSON_GetProperties' \
string:'{
	"inprop": ["ETC_DatabaseVersion",
	"ETC_SoftwareVersion"]
}' > $_OUTPUT_DIR_/nav_version.log

pidin > $_OUTPUT_DIR_/threads.log

_FAST_=1
_FAST_TXT_FILE_=$_OUTPUT_DIR_/fast.txt
_FAST_HTML_FILE_=$_OUTPUT_DIR_/fast.html
_FAST_TIME_CSV_FILE_=$_OUTPUT_DIR_/fast_time.csv
_FAST_DIST_CSV_FILE_=$_OUTPUT_DIR_/fast_dist.csv

_SHORT_=2
_SHORT_TXT_FILE_=$_OUTPUT_DIR_/short.txt
_SHORT_HTML_FILE_=$_OUTPUT_DIR_/short.html
_SHORT_TIME_CSV_FILE_=$_OUTPUT_DIR_/short_time.csv
_SHORT_DIST_CSV_FILE_=$_OUTPUT_DIR_/short_dist.csv

_SCENIC_=4
_SCENIC_TXT_FILE_=$_OUTPUT_DIR_/scenic.txt
_SCENIC_HTML_FILE_=$_OUTPUT_DIR_/scenic.html
_SCENIC_TIME_CSV_FILE_=$_OUTPUT_DIR_/scenic_time.csv
_SCENIC_DIST_CSV_FILE_=$_OUTPUT_DIR_/scenic_dist.csv

_SPORT_=524288
_SPORT_TXT_FILE_=$_OUTPUT_DIR_/sport.txt
_SPORT_HTML_FILE_=$_OUTPUT_DIR_/sport.html
_SPORT_TIME_CSV_FILE_=$_OUTPUT_DIR_/sport_time.csv
_SPORT_DIST_CSV_FILE_=$_OUTPUT_DIR_/sport_dist.csv

_FAST_WITH_AVOID_=27065
_FAST_AVOID_TXT_FILE_=$_OUTPUT_DIR_/fast_avoid.txt
_FAST_AVOID_HTML_FILE_=$_OUTPUT_DIR_/fast_avoid.html
_FAST_AVOID_TIME_CSV_FILE_=$_OUTPUT_DIR_/fast_avoid_time.csv
_FAST_AVOID_DIST_CSV_FILE_=$_OUTPUT_DIR_/fast_avoid_dist.csv

_SHORT_WITH_AVOID_=27066
_SHORT_AVOID_TXT_FILE_=$_OUTPUT_DIR_/short_avoid.txt
_SHORT_AVOID_HTML_FILE_=$_OUTPUT_DIR_/short_avoid.html
_SHORT_AVOID_TIME_CSV_FILE_=$_OUTPUT_DIR_/short_avoid_time.csv
_SHORT_AVOID_DIST_CSV_FILE_=$_OUTPUT_DIR_/short_avoid_dist.csv

_SCENIC_WITH_AVOID_=27068
_SCENIC_AVOID_TXT_FILE=$_OUTPUT_DIR_/scenic_avoid.txt
_SCENIC_AVOID_HTML_FILE=$_OUTPUT_DIR_/scenic_avoid.html
_SCENIC_AVOID_TIME_CSV_FILE_=$_OUTPUT_DIR_/scenic_avoid_time.csv
_SCENIC_AVOID_DIST_CSV_FILE_=$_OUTPUT_DIR_/scenic_avoid_dist.csv

_SPORT_WITH_AVOID_=551352
_SPORT_AVOID_TXT_FILE_=$_OUTPUT_DIR_/sport_avoid.txt
_SPORT_AVOID_HTML_FILE_=$_OUTPUT_DIR_/sport_avoid.html
_SPORT_AVOID_TIME_CSV_FILE_=$_OUTPUT_DIR_/sport_avoid_time.csv
_SPORT_AVOID_DIST_CSV_FILE_=$_OUTPUT_DIR_/sport_avoid_dist.csv

#Fast,Short,Scenic,Sport(FSSS)
_FSSS_TXT_FILE_=$_OUTPUT_DIR_/fsss.txt
_FSSS_HTML_FILE_=$_OUTPUT_DIR_/fsss.html
_FSS_TIME_CSV_FILE_=$_OUTPUT_DIR_/fss_time.csv
_FSS_DIST_CSV_FILE_=$_OUTPUT_DIR_/fss_dist.csv

_FSSS_AVOID_TXT_FILE_=$_OUTPUT_DIR_/fsss_avoid.txt
_FSSS_AVOID_HTML_FILE_=$_OUTPUT_DIR_/fsss_avoid.html
_FSS_AVOID_TIME_CSV_FILE_=$_OUTPUT_DIR_/fss_avoid_time.csv
_FSS_AVOID_DIST_CSV_FILE_=$_OUTPUT_DIR_/fss_avoid_dist.csv

chmod 777 $_BIN_DIR_/RouteRegression

echo "Measuring for fast route"
$_BIN_DIR_/RouteRegression --tp=$_BIN_DIR_/RouteRegression.hbtc --inputfile=$_BIN_DIR_/PositionFile.txt --routeoptions=$_FAST_ --textoutput=$_FAST_TXT_FILE_ --htmloutput=$_FAST_HTML_FILE_ --calctimeoutput=$_FAST_TIME_CSV_FILE_ --distanceoutput=$_FAST_DIST_CSV_FILE_
echo "Finished measuring for fast route"

echo "Measuring for short route"
$_BIN_DIR_/RouteRegression --tp=$_BIN_DIR_/RouteRegression.hbtc --inputfile=$_BIN_DIR_/PositionFile.txt --routeoptions=$_SHORT_ --textoutput=$_SHORT_TXT_FILE_ --htmloutput=$_SHORT_HTML_FILE_ --calctimeoutput=$_SHORT_TIME_CSV_FILE_ --distanceoutput=$_SHORT_DIST_CSV_FILE_
echo "Finished measuring for short route"

echo "Measuring for scenic route"
$_BIN_DIR_/RouteRegression --tp=$_BIN_DIR_/RouteRegression.hbtc --inputfile=$_BIN_DIR_/PositionFile.txt --routeoptions=$_SCENIC_ --textoutput=$_SCENIC_TXT_FILE_ --htmloutput=$_SCENIC_HTML_FILE_ --calctimeoutput=$_SCENIC_TIME_CSV_FILE_ --distanceoutput=$_SCENIC_DIST_CSV_FILE_
echo "Finished measuring for scenic route"

echo "Measuring for sport route"
$_BIN_DIR_/RouteRegression --tp=$_BIN_DIR_/RouteRegression.hbtc --inputfile=$_BIN_DIR_/PositionFile.txt --routeoptions=$_SPORT_ --textoutput=$_SPORT_TXT_FILE_ --htmloutput=$_SPORT_HTML_FILE_ --calctimeoutput=$_SPORT_TIME_CSV_FILE_ --distanceoutput=$_SPORT_DIST_CSV_FILE_
echo "Finished measuring for sport route"

echo "Measuring for fast with avoid options route"
$_BIN_DIR_/RouteRegression --tp=$_BIN_DIR_/RouteRegression.hbtc --inputfile=$_BIN_DIR_/PositionFile.txt --routeoptions=$_FAST_WITH_AVOID_ --textoutput=$_FAST_AVOID_TXT_FILE_ --htmloutput=$_FAST_AVOID_HTML_FILE_ --calctimeoutput=$_FAST_AVOID_TIME_CSV_FILE_ --distanceoutput=$_FAST_AVOID_DIST_CSV_FILE_
echo "Finished measuring for fast with avoid options route"

echo "Measuring for short with avoid options route"
$_BIN_DIR_/RouteRegression --tp=$_BIN_DIR_/RouteRegression.hbtc --inputfile=$_BIN_DIR_/PositionFile.txt --routeoptions=$_SHORT_WITH_AVOID_ --textoutput=$_SHORT_AVOID_TXT_FILE_ --htmloutput=$_SHORT_AVOID_HTML_FILE_ --calctimeoutput=$_SHORT_AVOID_TIME_CSV_FILE_ --distanceoutput=$_SHORT_AVOID_DIST_CSV_FILE_
echo "Finished measuring for short with avoid options route"

echo "Measuring for scenic with avoid options route"
$_BIN_DIR_/RouteRegression --tp=$_BIN_DIR_/RouteRegression.hbtc --inputfile=$_BIN_DIR_/PositionFile.txt --routeoptions=$_SCENIC_WITH_AVOID_ --textoutput=$_SCENIC_AVOID_TXT_FILE --htmloutput=$_SCENIC_AVOID_HTML_FILE --calctimeoutput=$_SCENIC_AVOID_TIME_CSV_FILE_ --distanceoutput=$_SCENIC_AVOID_DIST_CSV_FILE_
echo "Finished measuring for scenic with avoid options route"

echo "Measuring for sport with avoid options route"
$_BIN_DIR_/RouteRegression --tp=$_BIN_DIR_/RouteRegression.hbtc --inputfile=$_BIN_DIR_/PositionFile.txt --routeoptions=$_SPORT_WITH_AVOID_ --textoutput=$_SPORT_AVOID_TXT_FILE_ --htmloutput=$_SPORT_AVOID_HTML_FILE_ --calctimeoutput=$_SPORT_AVOID_TIME_CSV_FILE_ --distanceoutput=$_SPORT_AVOID_DIST_CSV_FILE_
echo "Finished measuring for sport with avoid options route"

echo "Measuring fast, short, scenic, sport together"
$_BIN_DIR_/RouteRegression --tp=$_BIN_DIR_/RouteRegression.hbtc --inputfile=$_BIN_DIR_/PositionFile.txt --routeoptions=$_FAST_,$_SHORT_,$_SCENIC_,$_SPORT_ --textoutput=$_FSSS_TXT_FILE_ --htmloutput=$_FSSS_HTML_FILE_ --calctimeoutput=$_FSS_TIME_CSV_FILE_ --distanceoutput=$_FSS_DIST_CSV_FILE_
echo "Finished measuring fast, short, scenic, sport together"

echo "Measuring fast, short, scenic, sport together with avoid options"
$_BIN_DIR_/RouteRegression --tp=$_BIN_DIR_/RouteRegression.hbtc --inputfile=$_BIN_DIR_/PositionFile.txt --routeoptions=$_FAST_WITH_AVOID_,$_SHORT_WITH_AVOID_,$_SCENIC_WITH_AVOID_,$_SPORT_WITH_AVOID_ --textoutput=$_FSSS_AVOID_TXT_FILE_ --htmloutput=$_FSSS_AVOID_HTML_FILE_ --calctimeoutput=$_FSS_AVOID_TIME_CSV_FILE_ --distanceoutput=$_FSS_AVOID_DIST_CSV_FILE_
echo "Finished measuring fast, short, scenic, sport together with avoid options"

echo "Finished RouteRegression"
