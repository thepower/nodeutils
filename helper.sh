#!/bin/bash

apt-get -y install socat > /dev/null

HOSTNAME=$(grep hostname /opt/thepower/node.config | cut -d '"' -f2)
if [ -z $HOSTNAME ]
  then HOSTNAME="Hostname not defined"
fi

PIDhttp=$(lsof -i :80 -t)
if [ $? != "0" ]
  then socat TCP4-LISTEN:80 - &
       PIDHTTP=$!  
       echo "Start listening to the port 80 ($PIDHTTP)"
  else echo "Port 80 is already in use ($PIDhttp)"
fi

PIDapi=$(lsof -i :1080 -t)
if [ $? != "0" ]
  then socat TCP4-LISTEN:1080 - &
       PIDAPI=$!
       echo "Start listening to the port 1080 ($PIDAPI)"
  else echo "Port 1080 is already in use ($PIDapi)"
fi

PIDapis=$(lsof -i :1443 -t)
if [ $? != "0" ]
  then socat TCP4-LISTEN:1443 - &
       PIDAPIS=$!
       echo "Start listening to the port 1443 ($PIDAPIS)"
  else echo "Port 1443 is already in use ($PIDapis)"
fi

PIDtpic=$(lsof -i :1800 -t)
if [ $? != "0" ]
  then socat TCP4-LISTEN:1800 - &
       PIDTPIK=$!
       echo "Start listening to the port 1800 ($PIDTPIK)"
  else echo "Port 1800 is already in use ($PIDtpic)"
fi

STATUS=$(curl -s http://ansible.thepower.io:26299)
IP=$(echo $STATUS | jq -r .ip)
API=$(echo $STATUS | jq -r .ports.api)
APIS=$(echo $STATUS | jq -r .ports.apis)
TPIC=$(echo $STATUS | jq -r .ports.tpic)
HTTP=$(echo $STATUS | jq -r .ports.http)

echo -e "\033[32m$HOSTNAME"
echo "  IP : $IP"
echo " API : $API"
echo "APIS : $APIS"
echo "TPIC : $TPIC"
echo "HTTP : $HTTP"
tput sgr0

if ps -p $PIDAPI > /dev/null; then kill -9 $PIDAPI; fi
if ps -p $PIDAPIS > /dev/null; then kill -9 $PIDAPIS; fi
if ps -p $PIDHTTP > /dev/null; then kill -9 $PIDHTTP; fi
if ps -p $PIDTPIK > /dev/null; then kill -9 $PIDTPIK; fi
