#!/bin/sh

export LD_LIBRARY_PATH=/mnt/app/root/lib-target:/eso/lib:/mnt/app/usr/lib:/mnt/app/armle/lib:/mnt/app/armle/lib/dll:/mnt/app/armle/usr/lib 
export IPL_CONFIG_DIR=/etc/eso/production 



#info
DESCRIPTION="This script will get info from a lot of persistence addresses and puts it out to sda0"
#optional inputs:
# $1: partition
# $2: start address
# $3: max address to be scanned

#Firmware/unit info:
VERSION="$(cat /net/rcc/dev/shmem/version.txt | grep "Current train" | sed 's/Current train = //g' | sed -e 's|["'\'']||g' | sed 's/\r//')"
FAZIT=$(cat /tmp/fazit-id);

echo "---------------------------"
echo "$DESCRIPTION" 
echo "FAZIT of this unit: $FAZIT"
echo "Firmware version: $VERSION"
echo "---------------------------"
sleep .5

#Is there any SD-card inserted?
if [ -d /net/mmx/fs/sda0 ]; then
    echo SDA0 found
    VOLUME=/net/mmx/fs/sda0
elif [ -d /net/mmx/fs/sdb0 ] ; then
    echo SDB0 found
    VOLUME=/net/mmx/fs/sdb0
else 
    echo No SD-cards found.
    exit 1
fi

#sleep .5

echo Mounting SD-card at $VOLUME.
mount -uw $VOLUME

sleep .5
echo Creating Dump folder on $VOLUME
DUMPFOLDER=$VOLUME/DUMP/$VERSION/$FAZIT/
mkdir -p $DUMPFOLDER

IDFILE=$DUMPFOLDER/id.txt

if [ "$3" != "" ]; then
    MAXSCAN=$3;
else
    MAXSCAN=100000000;
    fi

echo "Scanning partition $PARTITION"

if [ "$2" != "" ]; then
    ADDRESS=$2;
    echo "Starting at $ADDRESS"
else
  if test -f "$IDFILE"; then
      echo "$IDFILE found"
      #read last known address from id-file
      read ADDRESS < $IDFILE
      echo "Continuing at $ADDRESS"
  else 
      echo "It looks like this is the first time scanning, starting at 0"
      ADDRESS=0
  fi 
fi

if [ "$1" != "" ]; then
  PARTITION=$1;
else
  PARTITION=0;
fi
#sleep .5

#starting loop

while [ $ADDRESS -le $MAXSCAN ]
do
  #echo "-----------------"
  echo "Scanning $PARTITION:$ADDRESS"
    
  #first check if ths address even exists or causes a time-out.
    PERSISTENCEDATA="$(on -f mmx on -f mmx /net/mmx/mnt/app/eso/bin/dumb_persistence_reader $PARTITION $ADDRESS 2>&1)"  
    if [[ "$PERSISTENCEDATA" == *"PERS_STATUS_TIMEOUT"* ]] ; then
      if echo $PARTITION $ADDRESS >> $DUMPFOLDER/persistence.txt ; then
        echo "TIMEOUT" >> $DUMPFOLDER/persistence.txt
        echo "Timeout, skipping address" 
        echo "" >> $DUMPFOLDER/persistence.txt
      else 
        echo "Scan cancelled"
        exit 1
      fi
    elif [[ "$PERSISTENCEDATA" == *" PERS_STATUS_TYPE_MISMATCH"* ]] ; then
      echo "Type mismatch, trying integer"
      PERSISTENCEDATAI="$(on -f mmx on -f mmx /net/mmx/mnt/app/eso/bin/dumb_persistence_reader $PARTITION $ADDRESS -t int 2>&1)"
        if [[ "$PERSISTENCEDATAI" == *"PERS_STATUS_TYPE_MISMATCH"* ]] ; then
          echo "Type mismatch, trying string"
          PERSISTENCEDATAS="$(on -f mmx on -f mmx /net/mmx/mnt/app/eso/bin/dumb_persistence_reader $PARTITION $ADDRESS -t string 2>&1)"
          if echo $PARTITION $ADDRESS "- string" >> $DUMPFOLDER/persistence.txt ; then
            echo $PERSISTENCEDATAS >> $DUMPFOLDER/persistence.txt
            echo "" >> $DUMPFOLDER/persistence.txt
            echo Data found: $PERSISTENCEDATAS
          else         
            echo "!Scan cancelled"
            exit 1
          fi
        elif [[ "$PERSISTENCEDATAI" != *"ERROR"* ]] ; then
          if echo $PARTITION $ADDRESS "- integer" >> $DUMPFOLDER/persistence.txt ; then
            echo $PERSISTENCEDATAI >> $DUMPFOLDER/persistence.txt
            echo "" >> $DUMPFOLDER/persistence.txt
            echo Data found: $PERSISTENCEDATAI
          else         
            echo "!Scan cancelled"
            exit 1
          fi         
        fi 
    elif [[ "$PERSISTENCEDATA" == *"PERS_STATUS_DOES_NOT_EXIST"* ]] ; then
          :
          #do nothing
    else 
      if echo $PARTITION $ADDRESS "- blob" >> $DUMPFOLDER/persistence.txt ; then
        echo $PERSISTENCEDATA >> $DUMPFOLDER/persistence.txt
        echo "" >> $DUMPFOLDER/persistence.txt
        echo Data found: $PERSISTENCEDATA
      else 
        echo "!Scan cancelled"
        exit 1
      fi

    fi
    
   


#increase the address with 1  
  ADDRESS=$(( $ADDRESS + 1 ))
  
  #only write the ID to the text once every 100 times, to speed up.
  if (( $ADDRESS % 100 == 0 ))
  then
    if echo $ADDRESS > $DUMPFOLDER/id.txt; then
    echo "writing to id.txt to save scan session"
    else 
      exit 1
    fi
  fi
  
done


# Make readonly again
mount -ur $VOLUME
echo Done

exit 0
