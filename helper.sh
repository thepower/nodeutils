#!/bin/bash

PLIST=""
declare -A PORTS
declare -A PST
PORTS["http"]="80"
PORTS["api"]="1080"
PORTS["apis"]="1443"
PORTS["tpic"]="1800"
NODECONFIG="/opt/thepower/node.config"
CHECKURL="http://help.thepower.io:26299"

HOSTNAME=$(grep hostname $NODECONFIG | cut -d '"' -f2)
DNSIP=""

# FIREWALL
echo -e "\033[35m\nCheck firewall ..."
tput sgr0

UFW=$(ufw status | grep -e "^Status")
UFWCLOSED=""
if [[ "$UFW" == *inactive* ]]
  then echo -e "\033[32mFirewall is inactive"; tput sgr0
  else echo -e "\033[33mFirewall is active"; tput sgr0
       for P in "${PORTS[@]}"
	 do
           ufw status | grep -e "\b$P\b" | grep "ALLOW" > /dev/null 2>&1
	   if [ "$?" -eq "0" ]
	   then 
	     echo -e "\033[32mPort ${PORTS[$P]} ($P) is open"
	     tput sgr0
           else
	     echo -e "\033[31mPort ${PORTS[$P]} ($P) is closed  by firewall"
	     tput sgr0
	     UFWCLOSED="1"
           fi
	 done
fi

if [ "$UFWCLOSED" == "1" ]
  then
echo -e "
\033[33mYou need to disable the firewall:
    \033[34mufw disable"
tput sgr0
echo -e "
\033[33mor open the ports:
    \033[34mufw allow proto tcp from any to any port 80,1080,1443,1800 comment \"tpnode\"
"
  else echo -e "\033[32mGood !"
fi
tput sgr0

# PORTS
echo -e "\033[35m\nCheck ports ..."
for P in "${PORTS[@]}"
  do
    PID=$(lsof -i :$P -t)
    if [ -z "$PID" ]
      then
	nc -l $P & > /dev/null 2>&1
        PL="$! "
        echo -e "\033[33mStart listening to the port $P ($PL)"
	PLIST="$PL $PLIST"
      else tput sgr0 ; echo "Port $P is already in use ($PID)"
    fi
  done	  

STATUS=$(curl -s $CHECKURL)
IP=$(echo $STATUS | jq -r .ip)

for P in "${!PORTS[@]}"
  do
    PST["$P"]="$(echo $STATUS | jq -r .ports.$P)"
  done

PORTCLOSED=""
for P in "${!PST[@]}"
  do
    if [ "${PST[$P]}" == "open" ]
      then echo -e "\033[32mPort $P : ${PST[$P]}"
      else echo -e "\033[31mPort $P : ${PST[$P]}"
	   PORTCLOSED="1"
    fi
  done

if [ -n "$PLIST" ]
  then kill -15 $PLIST > /dev/null 2>&1
fi

if [ "$PORTCLOSED" == "1" ]
  then echo -e "\033[31mYou need to open the ports"
  else echo -e "\033[32mGood !"
fi
tput sgr0

# DNS
echo -e "\033[35m\nCheck DNS ..."
if [ -z $HOSTNAME ]
  then echo -e "\033[31mHostname not defined !"; tput sgr0
  else DNSIP=$(dig +short $HOSTNAME)
echo -e "\033[35mHostname : $HOSTNAME"
echo -e "\033[34m      ip : $IP"
echo -e "\033[34m   dnsip : $DNSIP"
fi


tput sgr0
