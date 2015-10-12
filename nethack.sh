#!/bin/bash
#This is a script for nethack
if [[ $1 == 0 ]]; then
  #This script is used to save the nethack game(Forgive my breaking the principle of roguelike games)
  DIR='/usr/games/bin/'
  SNAME=$HOME/.nethack/save
  BNAME=$HOME/.nethack/bak
  if [ `ls $DIR/save | wc -w` == '0' ]; then
    sudo ln -f $DIR/bak/$BNAME $DIR/save/$BNAME
    echo 'The file is recovered'
  else
    echo 'The file is back up'
    sudo ln -f $DIR/save/$SNAME $DIR/bak/$SNAME
  fi
else
  #This is to open the nethack in a right way
  nethack
fi
