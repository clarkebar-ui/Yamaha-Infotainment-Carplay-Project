#!/bin/sh

MMC0_File=/fs/mmc0/MMC0Checksum.txt

FULLPATH=$(cd "$(dirname "$0")"; pwd) #

echo "============MMC0 check============"
echo "Start MMC0 test time: `date`"
rm -rf /fs/mmc0/MMC0Checksum.txt
touch /fs/mmc0/MMC0Checksum.txt

grep MMC /fs/mmc0/mmcChecksumFile.txt > $MMC0_File
#grep ETFS /fs/etfs/scripts/etfsChecksumFile.txt > $MMC0_File

echo "******************************************************************************"
FAIL=0
#Check Magic File Integrity
#Magic_File_Checksum_Src=$(grep ETFS /fs/etfs/scripts/etfsChecksumFile.txt | cksum | awk '{print $1}')
Magic_File_Checksum_Src=$(grep MMC /fs/mmc0/mmcChecksumFile.txt | cksum | awk '{print $1}')
Magic_File_Checksum_Target=$(cksum $MMC0_File | awk '{print $1}')
if [[ $Magic_File_Checksum_Src = $Magic_File_Checksum_Target ]] then
    echo "Magic file $MMC0_File check pass: Acutal: $Magic_File_Checksum_Src == target: $Magic_File_Checksum_Target"
    echo "MMC0 Magic file check passed"
else
    echo "Magic file $MMC0_File check failed: Acutal: $Magic_File_Checksum_Src != target: $Magic_File_Checksum_Target"
    echo "MMC0 Magic file check failed"
    FAIL=1
    exit 1
fi

while read var1 var2 var3 var4;
do 
    Stored_Checksum=$var2
    #echo "varifying for $var4"
    #echo "Stored cksum: $Stored_Checksum"
    #echo "***$var4***"
    #cksum $var4
    Calc_Checksum=$(cksum $var4 | awk '{print $1}')
    #echo "Calc_Checksum $Calc_Checksum"
    if [[ $Stored_Checksum = $Calc_Checksum ]] then
		echo "MMC0 file '$var4' check pass: Acutal: $Stored_Checksum == target: $Calc_Checksum"
	else
		echo "MMC0 file '$var4' check failed: Acutal: $Stored_Checksum != target: $Calc_Checksum"
		FAIL=1
	fi
    done < $MMC0_File

echo "End MMC0 test time: `date`"

if ((FAIL > 0)) then
	exit 1
else
	exit 0
fi