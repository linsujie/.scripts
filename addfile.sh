#!/bin/bash
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#This script is to move the file with filename.pdf in Dowloads/ to Documents/Reference/ with key.pdf; then link the file key.pdf with the item "key" in bibus
user=linsj
bibusdata=~/.bibus/Data/Daily.db
tmpfile=~/Documents/tmp.bib

filename=$1
key=`cat $tmpfile | awk '{if(NR==1) print}' |sed -e "s/@article{//g" -e "s/://g" -e "s/\([0-9]\{4\}\)[a-z]\{1,5\},//g"`
year=`cat $tmpfile | grep -G "year\s+= \"\{0,1\}[0-9]\{4\}\"\{0,1\}" | sed -e "s/year\s+= \"\{0,1\}\([0-9]\{4\}\)\"\{0,1\}/\1/g"`
read -p "The key is $key, do you want to add postfix to it?
" postfix
key=$key$year$postfix
echo The key is $key now
if [ -e ~/Downloads/$filename ] ; then
 # mv ~/Downloads/$filename ~/Documents/Reference/$key".pdf"
 # sqlite3 $bibusdata "update bibref set URL='/home/$user/Documents/Reference/$key.pdf' where identifier='$key'"
  echo "aaa"
else
  echo "file not exist"
  sqlite3 $bibusdata "update bibref set URL='/home/$user/Documents/Reference/$key.pdf' where identifier='$key'"
fi
