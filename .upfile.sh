#!/bin/bash
#This script will keep the $DIR2 the same as $DIR1, for Chinese and diff of version 3.2 only
DIR1=$1
DIR2=$2
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
for i in `diff -qr $DIR1 $DIR2 | awk '/：/{string=$3;string=substr(string,4);print $2"/"string;}'`
do
  if [ `expr match "$i" $DIR1` != 0 ] ; then
    cp $i ${i/$DIR1/$DIR2}
    echo "File $i is backup"
  fi
  if [ `expr match "$i" $DIR2` != 0 ] ; then
    rm $i
    echo "The old file $i is removed"
  fi
done
num=1
for i in `diff -qr $DIR1 $DIR2 | awk '/文件/{print $2,$4}'`
do
  if [ $num == 1 ] ; then
    file1=$i
    num=2
  else
    file2=$i
    cp $file1 $file2
    echo "$file2 is update with $file1"
    num=1
  fi
done
