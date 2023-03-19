#!/bin/bash

PLIST=""
declare -A PORTS
declare -A PST
PORTS["http"]="80"
PORTS["api"]="1080"
PORTS["apis"]="1443"
PORTS["tpic"]="1800"
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
        echo -e "\033[33mStart listening to the port $P ($PL)"
	PLIST="$PL $PLIST"
      else tput sgr0 ; echo "Port $P is already in use ($PID)"
    fi
  done	  

STATUS=$(curl -s http://ansible.thepower.io:26299)
IP=$(echo $STATUS | jq -r .ip)

for P in "${!PORTS[@]}"
  do
    PST["$P"]="$(echo $STATUS | jq -r .ports.$P)"
  done

echo -e "\033[35m$HOSTNAME"
echo -e "\033[34mip : $IP"

for P in "${!PST[@]}"
  do
    if [ "${PST[$P]}" == "open" ]
      then echo -e "\033[32m$P : ${PST[$P]}"
      else echo -e "\033[31m$P : ${PST[$P]}"
    fi
  done

tput sgr0

if [ -n "$PLIST" ]
  then kill -9 $PLIST 2> /dev/null
fi

