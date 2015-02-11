#!/bin/bash
read -p "Which server do you want to login? 1.sv1 2.sv2 3.lxslc 4.bixj" switch
if [ $switch == "1" ]; then
  username="jagee"
  server="192.168.238.153"
  passwd="7800565"
elif [ $switch == "2" ]; then
  username="jagee"
  server="192.168.238.154"
  passwd="lsj7800565"
elif [ $switch == "3" ]; then
  username="yuzh"
  server="lxslc.ihep.ac.cn"
  passwd="123darkmatter"
elif [ $switch == "4" ]; then
  username="lsj"
  server="192.168.234.143"
  passwd="lsj7800565"
fi
export username
export server
export passwd
read -p "Do you want to use expect?" expect
if [ $expect == "y" ]; then
~/.scripts/login.sh $username $server $passwd
elif [ $expect == "n" ]; then
ssh -X $username@$server
fi
