#!/bin/sh
swi=$1
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#Initial table
i=1
for name in 'WIN7' 'Program' 'FREE' 'DATA'
do
DISKNAME[i]=$name
i=`echo $i | awk '{print $1+1}'`
done

i=1
for name in 'sda1' 'sda5' 'sda6' 'sda7'
do
DISK[i]=$name
i=`echo $i | awk '{print $1+1}'`
done
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#Check which disk is mounted, and generate the list
for i in `seq 4`
do
  if [ -e /media/${DISKNAME[i]} ] ;then
    MODDISKNAME[i]=${DISKNAME[i]}'*'
  else
    MODDISKNAME[i]=${DISKNAME[i]}
  fi
    DISKLIST=$DISKLIST$i'.'${MODDISKNAME[i]}' '
done
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++
if [ $swi == '1' ] ;then
  echo "Which disk would you like to mount?"
  echo $DISKLIST
  read num
  if [ ! -e /media/${DISKNAME[num]} ] ; then
    sudo mkdir /media/${DISKNAME[num]}
  fi
   sudo mount -o iocharset=utf8,uid=Jagee,gid=500,fmask=133,dmask=022 /dev/${DISK[num]} /media/${DISKNAME[num]}
elif [ $swi == '-1' ] ;then
  echo "Which disk would you like to umount?"
  echo $DISKLIST
  read num
  if [ -e /media/${DISKNAME[num]} ] ;then
    sudo umount /media/${DISKNAME[num]}
    if [ `ls /media/${DISKNAME[num]}| wc -w` == 0 ] ;then
      sudo rm -r /media/${DISKNAME[num]}
    fi
  fi
fi

