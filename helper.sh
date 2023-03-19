#!/bin/bash

PLIST=""
declare -A PORTS
PORTS["HTTP"]="80"
PORTS["API"]="1080"
PORTS["APIS"]="1443"
PORTS["TPIC"]="1800"
NODECONFIG="/opt/thepower/node.config"

dpkg -s socat 2>1 1> /dev/null
if [ "$?" != "0"  ]
  then
    echo -e "\033[33mThe \033[1;33msocat\033[0;33m package will be installed"
    tput sgr0
    apt-get -y install socat 2>1 > /dev/null
fi

HOSTNAME=$(grep hostname $NODECONFIG | cut -d '"' -f2)

if [ -z $HOSTNAME ]
  then HOSTNAME="Hostname not defined"
fi

for P in "${PORTS[@]}"
  do
    PID=$(lsof -i :$P -t)
    if [ "$?" != "0" ]
      then
	socat TCP4-LISTEN:$P - &
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

