#!/bin/bash
expect << EOF
spawn modify_firewall -o open -p 161 -t udp -i eth0 -a
expect "Do you wish to*"
send "y\r"
expect eof;
EOF
