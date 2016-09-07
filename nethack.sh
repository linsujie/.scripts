#!/bin/bash
#This is a script for nethack
DIR='/usr/games/'
if [[ $1 == 0 ]]; then
  #This script is used to save the nethack game(Forgive my breaking the principle of roguelike games)
  SNAME=$DIR/lib/nethackdir/save/1000linsj.gz
  BNAME=$DIR/lib/nethackdir/backup/1000linsj.gz
  if [[ -e $SNAME ]]; then
    echo 'The file is back up'
    sudo ln -f $SNAME $BNAME
  else
    sudo ln -f $BNAME $SNAME
    echo 'The file is recovered'
  fi
else
  #This is to open the nethack in a right way
  echo $DIR/nethack
  $DIR/nethack
fi
