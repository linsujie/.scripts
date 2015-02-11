#!/bin/bash
#if the file is zipfile use another method to dtrx is
fname=$1
relic=`echo $1 | grep -e '\.'zip$`
if [[ $relic == '' ]]; then
   /bin/dtrx $1
else
  dirname=${fname:0:${#fname}-4}
  dir=`basename $dirname`
  echo $dir
  mkdir $dir
  odir=`pwd`
  cd $dir
  ~/.scripts/.conv.py $odir/$fname
fi
