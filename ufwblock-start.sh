#! /bin/bash

# Add ufw rules to allow traffic from specified addresses

URL="http://www.ipdeny.com/ipblocks/data/countries/pl.zone"
PORTS="65432 8006"
ALWAYS_ALLOWED="192.168.0.0/16 10.10.1.0/16"
MIN_RULES=1
RULES_FILE="/etc/ufw/before.rules"
NEW_RULES_FILE="./before.rules.new"
DATE=$(date "+%Y%M%d")
RULES_BACKUP="./before.rules.$DATE"

RULES_TO_ADD=()

add_rule () {
  # add ufw rule
  # $1 -> addr, $2..$n PORTS to allow
  IP=$1
  RET=""
  shift
  for PORT in $@; do
    #echo "  IP: $IP  PORT: $PORT"
    ENTRY="-A from-country -p tcp --dport $PORT -s $IP -j ACCEPT"
    RULES_TO_ADD+=("$ENTRY")
  done
  # ugly return text
 
}

check_entry () {
  # check if IP is in proper form 
  # $1 -> IP ADDR BLOCK in ipv4 format
  if [[ $1 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\/[0-9]{1,2} ]] ; then
    #echo "IP $1 OK"
    return 0
  else 
    #echo "IP $1 BAD"
    return 1
  fi
}

add_rule_url () {
  # add rules for IP from url
  # $1-> ip list url, $2..$n -> PORTS to allow
  URL=$1
  shift
  PORTS=$@
  for IP in $(wget -q -O - $URL); do
    #echo "Allow from: $IP"
    if check_entry $IP ;  then
      add_rule $IP $@
    fi
  done
}

add_rule_str () {
  # add rules for IP from string 
  # $1-> ip, $2..$n -> PORTS to allow
  IPOK=$1
  shift
  for IP in $IPOK ;  do
    #echo "Allow from: $IP"
    if check_entry $IP ;  then
      add_rule $IP $@
    fi
  done
}

add_block_rule () {
  # add final block rule at the end
  # $1..$n -> PORTS to block
  for PORT in $@; do
    #echo "  final block for PORT: $PORT"
    ENTRY="-A from-country -p tcp --dport $PORT  -j DENY"
    RULES_TO_ADD+=("$ENTRY")
  done
}

check_url_list () {
  # check if list taken from URL is OK
  # $1 -> URL
  URL=$1

  TEST=$(wget -O - $URL -q | wc -l )
  if [ ${TEST} -lt 1 ]; then
    echo "Could not download proper IP ADDR list. Exiting."
    exit
  fi

  let ipbad=0
  let ipok=0
  for IP in $(wget -q -O - $URL); do
    #echo "Allow from: $IP"
    if check_entry $IP ;  then
      let ipok=$ipok+1
    else
      let ipbad=$ipbad+1
      echo "Bad ip block: $IP"
    fi
  done

  if [ $ipok -lt $MIN_RULES ] ; then
    echo "Number of proper rules is less than $MIN_RULES. Could not process, exiting."
   exit
  fi

}

# check if list seems to be legit

LISTA=""

# check if list is OK
check_url_list $URL


# add local static entries
for IP in $ALWAYS_ALLOWED; do
   add_rule_str $IP $PORTS
done

# add entries from list
add_rule_url $URL $PORTS

# add final block section
add_block_rule $PORTS

# process and commit
if [ ${#RULES_TO_ADD[@]} -lt $MIN_RULES ]; then
  echo "Nuber of final rules seems to be too low. exiting."
  exit
else
  echo "We've got ${#RULES_TO_ADD[@]} rules to add"
fi


# clean output file
echo "" > ${NEW_RULES_FILE}
SKIP_ENTRIES=0

# create new rules file
while IFS= read -r line
do
  if [ "$line" == "#FROM-COUNTRY BLOCK BEGINS" ] ; then
    echo "$line" >> ${NEW_RULES_FILE}


  for ((i = 0; i < ${#RULES_TO_ADD[@]}; i++))
  do
    echo "${RULES_TO_ADD[$i]}" >> ${NEW_RULES_FILE}
  done

    SKIP_ENTRIES=1
  fi

  if [ "$line" == "#FROM-COUNTRY BLOCK ENDS" ] ; then
    SKIP_ENTRIES=0
  fi
  
  if [ $SKIP_ENTRIES -eq 0 ] ; then
    #copy enties if not inside our block
    echo "$line" >> ${NEW_RULES_FILE}
  fi

done < "$RULES_FILE"


# final sanity check
LINES1=$(wc -c "$RULES_FILE" | awk '{print $1}')
LINES2=$(wc -c "$NEW_RULES_FILE" | awk '{print $1}')

# echo "old: $LINES1 new: $LINES2"
if [ $LINES2 -gt $LINES1 ] ; then
  cat $RULES_FILE > $RULES_BACKUP
  # file seems to be OK
  echo "Saving new rules."
  cat $NEW_RULES_FILE > $RULES_FILE

  # reload rules
  ufw reload
fi

