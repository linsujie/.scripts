#!/usr/bin/expect
#set timeout 10
set username [lindex $argv 0]
set server [lindex $argv 1]
set passwd [lindex $argv 2]
spawn ssh -X $username@$server
expect "password:"
sleep 0.1
send $passwd\n
expect eof
interact
exit

