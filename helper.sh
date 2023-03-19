#!/bin/bash

apt-get -y install socat > /dev/null

HOSTNAME=$(grep hostname /opt/thepower/node.config | cut -d '"' -f2)
if [ -z $HOSTNAME ]
  then HOSTNAME="Hostname not defined"
fi

PLIST=""

for P in "80" "1080" "1443" "1800"
  do
    PID=$(lsof -i :$P -t)
    if [ $? != "0" ]
      then socat TCP4-LISTEN:$P - &
        PL="$! "
        echo "Start listening to the port $P ($PL)"
	PLIST="$PL $PLIST"
      else echo "Port $P is already in use ($PID)"
    fi
  done	  

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

if [ -n "$PLIST" ]
  then kill -9 $PLIST 2> /dev/null
fi

