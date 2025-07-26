#!/bin/sh
#    
#   Author: Ravi Gupta
#   Email:  ravishankar.gupta@harman.com
#
IPL_RESULT=PASS;
IFS_RESULT=PASS;
ETFS_RESULT=PASS;
echo "Tests in Progress...";
while read var1 var2 var3 var4;
do
    case "$var1" in
        "IPL")
            for i in 0 1 2 3
            do
                iplTestCmd=`imageChecksumUtility -i -p $i`;
                echo $iplTestCmd | grep $var3 > /dev/null;
                if [ $? != 0 ]; then
                    IPL_RESULT=FAIL;
                fi
            done
            echo "IPL TEST RESULT: $IPL_RESULT";
        ;;
        "IFS")
            for i in 0 1 2
            do
                ifsTestCmd=`imageChecksumUtility -p $i`;
                echo $ifsTestCmd | grep $var3 > /dev/null;
                if [ $? != 0 ]; then
                    IFS_RESULT=FAIL;
                fi
            done
            echo "IFS TEST RESULT: $IFS_RESULT";
        ;;
        "ETFS")
            checksumCmd=`cksum "$var4"`;
            echo $checksumCmd | grep $var2 > /dev/null;
            if [ $? != 0 ]; then 
                ETFS_RESULT=FAIL;
                echo "Etfs Checksum test failed for $var4";
            fi
        ;;
    esac
done < /fs/etfs/scripts/etfsChecksumFile.txt
echo "ETFS TEST RESULT: $ETFS_RESULT";
if [ $IPL_RESULT == PASS ] && [ $IFS_RESULT == PASS ] && [ $ETFS_RESULT == PASS ]; then
    echo "FINAL TEST RESULT: PASS";
else
    echo "FINAL TEST RESULT: FAIL";
fi
