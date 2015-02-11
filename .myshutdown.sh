#!/bin/bash
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#tasks before shutdown/reboot
~/.scripts/.autoumount

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
if [ $1 == 0 ] ; then
  sudo shutdown now
elif [ $1 == 1 ] ; then
  reboot
fi
