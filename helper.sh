#!/bin/bash
#
# A small script that checks the basic settings for the normal functioning of the node
# The script is designed for a node installed according to the official instructions
# Even if the script completes without errors, this does not guarantee the correct operation of the node
# It is impossible to provide for all possible configurations of the systems,
# so there are no guarantees of the absence of errors
# Bug reports and participation in the expansion of the script functionality are welcome

PLIST=""
declare -A PORTS
declare -A PST
PORTS["http"]="80"
PORTS["api"]="1080"
PORTS["apis"]="1443"
PORTS["tpic"]="1800"
NODECONFIG="/opt/thepower/node.config"
CHECKURL="http://help.thepower.io:26299"

echo "Script for checking basic settings"

apt-get -y install jq > /dev/null 2>&1

HOSTNAME=""
if [ ! -f "$NODECONFIG" ]
  then DOCKERNAME="$(docker ps --format '{{.Image}} {{.Names}}' 2>/dev/null | grep 'thepowerio/tpnode' | cut -d ' ' -f2 )"
    if [ -n "$DOCKERNAME" ]
      then NODECFG=$(docker inspect $DOCKERNAME | jq -r '.[].Mounts[] | select(.Destination == "/opt/thepower/node.config") | .Source')
	if [ -n "$NODECFG" ]
          then NODECONFIG=$NODECFG
	fi	
    fi
fi

if [ ! -f "$NODECONFIG" ]
  then NODECFG=$(find /opt -name node.config -print 2>/dev/null | head -n1)
    if [ -n "$NODECFG" ]
      then NODECONFIG=$NODECFG
    fi	
fi

if [ -f "$NODECONFIG" ]
  then echo -e "\033[33m\nUse the node configuration file: \033[1m$NODECONFIG";tput sgr0
       HOSTNAME=$(grep hostname $NODECONFIG | cut -d '"' -f2 2> /dev/null)
  else echo -e "\033[31m\nFile $NODECONFIG not found"; tput sgr0
fi
DNSIP=""

# FIREWALL
echo -e "\033[35m\nCheck firewall ..."; tput sgr0
FWOK="1"
tput sgr0

UFW=$(ufw status | grep -e "^Status")
UFWCLOSED=""
if [[ "$UFW" == *inactive* ]]
  then echo -e "\033[32mFirewall is inactive"; tput sgr0
  else echo -e "\033[33mFirewall is active"; tput sgr0
       for P in "${!PORTS[@]}"
	 do
           ufw status | grep -e "\b${PORTS[$P]}\b" | grep "ALLOW" > /dev/null 2>&1
	   if [ "$?" -eq "0" ]
	   then 
             echo -e "\033[32mPort $P (${PORTS[$P]}) is open"
	     tput sgr0
           else
	     echo -e "\033[31mPort $P (${PORTS[$P]}) is closed  by firewall"
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
echo -e "\033[33mor open the ports:
  \033[34mufw allow proto tcp from any to any port 80,1080,1443,1800 comment \"tpnode\""
  else echo -e "\033[32mGood !"; FWOK="0"
fi
tput sgr0

# PORTS
echo -e "\033[35m\nCheck ports ..."; tput sgr0
PORTOK="1"
for P in "${PORTS[@]}"
  do
    PID=$(lsof -i :$P -t | head -n1)
    if [ -z "$PID" ]
      then
	nc -l $P & > /dev/null 2>&1
        PL="$!"
        echo "Start listening to the port $P ($PL)"
	PLIST="$PL $PLIST"
      else
	PNAME="$(ps -p $PID -o comm=)" 
	echo -e "\033[33mPort $P is occupied by process \033[1m$PNAME\033[0m ($PID)"; tput sgr0 
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
  then echo -e "\033[31mYou need to open the ports. Check your firewall"
  else echo -e "\033[32mGood !"; PORTOK="0"
fi
tput sgr0

# DNS
echo -e "\033[35m\nCheck DNS ..."
DNSOK="1"
if [ -z "$HOSTNAME" ]
  then echo -e "\033[31mHostname not defined !"
       echo -e "\033[34mPublic IP : $IP"; tput sgr0
  else DNSIP=$(dig @8.8.8.8 +short $HOSTNAME)
    echo -e "\033[34m Hostname : $HOSTNAME"
    echo -e "\033[34mPublic IP : $IP"
    echo -e "\033[34m   DNS IP : $DNSIP"
    if [ "$IP" != "$DNSIP" ]
      then echo -e "\033[31mCheck your DNS settings!"
      else echo -e "\033[32mGood !"; DNSOK="0"
    fi
fi
tput sgr0

# SSL/TLS
echo -e "\033[35m\nCheck SSL ..."; tput sgr0
SSLOK="1"
if [ -z "$HOSTNAME" ]
  then echo -e "\033[31mHostname not defined !"; tput sgr0
  else
    CRT="/opt/thepower/db/cert/${HOSTNAME}.crt"
    KEY="/opt/thepower/db/cert/${HOSTNAME}.key"
    CA="/opt/thepower/db/cert/${HOSTNAME}.crt.ca.crt"
    if [ -f "$CRT" -a -f "$KEY" -a -f "$CA" ]
      then
	KEYPUB="$(openssl rsa -in $KEY -pubout 2> /dev/null)"
	  if [ "$?" != "0" ]
            then KEYPUB="$(openssl ec -in $KEY -pubout 2> /dev/null)"
	      if [ "$?" != "0" ]
		then echo -e "\033[31mUnknown key type !";tput sgr0
	      fi
	  fi
	CRTPUB="$(openssl x509 -in $CRT -pubkey -noout 2> /dev/null)"
        if [ "$KEYPUB" == "$CRTPUB" ]
#          then openssl verify -CAfile $CA $CRT > /dev/null 2>&1
          then openssl verify -untrusted $CA $CRT > /dev/null 2>&1
	    if [ $? == "0" ]
	      then
		CRTNAME="$(openssl x509 -in $CRT -text -noout | grep "Subject: CN" | tr -d ' ' | cut -d '=' -f2)"
		if [ "$HOSTNAME" == "$CRTNAME" ]
	          then echo -e "\033[32mGood !"; tput sgr0; SSLOK="0"
		  else echo -e "\033[31mCertificate issued for another domain !"; tput sgr0
		fi
	      else echo -e "\033[31mProblems with trusting serificate !"; tput sgr0
            fi 
          else echo -e "\033[31mThe key does not match the certificate !"; tput sgr0
        fi
      else echo -e "\033[31mNot all SSL files found !"; tput sgr0
    fi
fi
tput sgr0

# acme.sh
if [ "$SSLOK" == "1" -a "$DNSOK" == "0" ]
  then 
echo -ne "\nDo you want to issue and install an SSL certificate?
The installation will be performed \033[1macme.sh\033[0m and an attempt to issue and install a certificate for domain \033[1m${HOSTNAME}\033[0m
A good idea? [y/n] : "
  read GI
  if [ "$GI" == "y" -o "$GI" == "Y" -o -z "$GI" ]
    then
      ACME="$(echo ~/.acme.sh/acme.sh)"
      if [ -x "$ACME" ]
	then echo -e "The \033[1macme.sh\033[0m  is already installed"
        else echo "Enter your email address. This is necessary to obtain an SSL certificate"
	     echo -n "email : "
	     read EMAIL
	     if [ -n "$EMAIL" ]
	       then apt-get -y install socat > /dev/null 2>&1
		    curl https://get.acme.sh | sh -s email=$EMAIL
	       else echo -e "\033[31mThe address cannot be empty !"; tput sgr0
		    exit 1
	     fi
      fi
      $ACME upgrade
      PID80=$(lsof -i :80 -t | head -n1)
      if [ -n "$PID80" ]
        then PNAME80="$(ps -p $PID80 -o comm=)"
	     echo -e "Port 80 is occupied by process \033[1m$PNAME80\033[0m ($PID80)"
	     echo "To issue a certificate, either stop this process and try again"
	     echo -e "or use the recommendations from the official documentation \033[1macme.sh\033[0m"
             echo -e "For example, if you use \033[1mnginx\033[0m:"
	     echo "  https://github.com/acmesh-official/acme.sh#7-use-nginx-mode"
	     exit 3
      fi
      if [ ${PST["http"]} != "open" ]
	then echo -e "\033[31mPort 80 is closed. Check your firewall and try again";tput sgr0 
	     exit 4
      fi 
      $ACME --issue --force --standalone -d $HOSTNAME  --keylength ec-256
      if [ "$?" == "0" ]
	then mkdir -p /opt/thepower/{db/cert,log}
	     $ACME --install-cert --ecc -d $HOSTNAME --cert-file $CRT --key-file $KEY --ca-file $CA
        else echo -e "\033[31mFailed attempt to issue a certificate"; tput sgr0
	     exit 2
      fi
    else echo -e "\033[33m\nYou need to install the certificates yourself according to the instructions"; tput sgr0
  fi
fi
tput sgr0
