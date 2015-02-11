#!/bin/bash
 file=$1
 yukiaddr=yuki@192.168.234.198:/home/yuki/
 echo "who do you want to sent the file to:"
 echo "0.do nothing"
 echo "1.Yuki"
 read name
 echo $file
# read -p "please determine which file do you want to sent:" file
 if [ "$name" == "1" ] ;then
    scp $file $yukiaddr
 fi

