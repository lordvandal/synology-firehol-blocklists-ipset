#!/bin/bash

## Based on the spamhaus-drop script by wallyhall, improved and tailored for Synology DSM 7.2
## Credit: https://github.com/wallyhall/spamhaus-drop

## Intially forked from cowgill, extended and improved for our mailserver needs.
## Credit: https://github.com/cowgill/spamhaus/blob/master/spamhaus.sh

# Inspired by the below code:
# http://www.theunsupported.com/2012/07/block-malicious-ip-addresses/
# http://www.cyberciti.biz/tips/block-spamming-scanning-with-iptables.html
# https://github.com/devrt/docker-firehol-update-ipsets

# Default blacklists: Firehol level 1, 2 and 3 lists from https://iplists.firehol.org/
#URLS="https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level1.netset https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level2.netset https://raw.githubusercontent.com/firehol/blocklist-ipsets/master/firehol_level3.netset"

# configuration folder
CONFIG_FOLDER="/firehol"

# local cache copy
CACHE_FILE="$CONFIG_FOLDER/firehol.blocklist.cache"

# use local block list file or option -m
# file must start with '/firehol/blocklist' to prevent misuse
LOCAL_BLACKLIST_FILE="$CONFIG_FOLDER/blocklist"

# use white list file or option -w
# file must start with '/firehol/whitelist' to prevent misuse
LOCAL_WHITELIST_FILE="$CONFIG_FOLDER/whitelist"

#  chain name
#CHAIN="INPUT"

# ipset set names
#IPSET="firehol-blocklist"
#IPSET_TMP="firehol-blocklist-tmp"

exit_cleanup() {
  if iptables_rule_exists; then
    delete_iptables_rule
  fi
  if ipset_exists; then
    destroy_ipset
  fi
  # remove our handler
  trap - SIGHUP SIGINT SIGTERM SIGKILL EXIT
}

trap_with_arg() {
    func="$1" ; shift
    for sig ; do
        trap "$func $sig" "$sig"
    done
}

trap_with_arg exit_cleanup SIGHUP SIGINT SIGTERM SIGKILL

error() {
  echo "$1" 1>&2
}

expand_cidr() {
  local cidr=$1
  local ip=$(echo $cidr | cut -d '/' -f 1)
  local prefix=$(echo $cidr | cut -d '/' -f 2)
  local IFS=.
  local -a octets=($ip)
  local bin_ip=""

  for octet in "${octets[@]}"; do
    bin_ip+=$(echo "obase=2; $octet" | bc | awk '{printf "%08d", $0}')
  done

  local num_ips=$(( 1 << (32 - prefix) ))
  local range_start=$(echo "ibase=2; $bin_ip" | bc)
  local range_end=$((range_start + num_ips - 1))

  for (( ip=range_start; ip<=range_end; ip++ )); do
    local ip1=$((ip>>24 & 0xFF))
    local ip2=$((ip>>16 & 0xFF))
    local ip3=$((ip>>8 & 0xFF))
    local ip4=$((ip & 0xFF))
    echo "${ip1}.${ip2}.${ip3}.${ip4}"
  done
}

netset_2_ipset() {
  while IFS= read -r line; do
    if echo "$line" | grep -q -E '^[^#]*/.+$'; then  # Check if the line is NOT a comment, BUT contains a CIDR notation
      expand_cidr "$line"
    else
      echo "$line"  # Output the line as is if it's not a CIDR notation
    fi
  done < "${1:-/dev/stdin}"
}

list_active_ipsets() {
  ipset list -n || ( ipset list | grep "^Name:" | cut -d: -f 2 )
}

ipset_exists() {
  # get all the active ipsets in the system
  for x in  $( list_active_ipsets ); do
    if [ "${x}" = "${IPSET}" ]; then
      return 0
    fi
  done
  return 1
}

iptables_rule_exists() {
  [[ -n `iptables-legacy -L $CHAIN | grep "match-set $1 src"` ]]
}

create_iptables_rule() {
  iptables-legacy -I "$CHAIN" -m set --match-set $IPSET src -j DROP
}

delete_iptables_rule() {
  iptables-legacy -D "$CHAIN" -m set --match-set $IPSET src -j DROP
}

destroy_ipset() {
  # destroy ipset if exists
  if ipset_exists; then
    ipset destroy "$IPSET" 2>/dev/null
  fi
}

download_rules() {
  local TMP_FILE="$(mktemp)"
  local WHITELIST_TMP_FILE="$(mktemp)"
	
  for URL in $URLS; do
    # get a copy of the spam list
    echo "Fetching '$URL' ..."
    curl -Ss "$URL" | grep -e "" | netset_2_ipset | tee -a "$TMP_FILE" > /dev/null 2>&1
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
      # Failed to download '$URL', continuing
      cat "$CACHE_FILE" >> "$TMP_FILE"
    fi
  done

  if [ -e "$LOCAL_BLACKLIST_FILE" ]; then
    grep -v "^#" "$LOCAL_BLACKLIST_FILE" | tee -a "$TMP_FILE" > /dev/null 2>&1
  fi

  # Removing comments (#,;) from the downloaded IP blacklist
  sed -i 's/\s*\(#\|;\).*$//' "$TMP_FILE"
  sed -i '/^\s*$/d' "$TMP_FILE"

  if [ -e "$LOCAL_WHITELIST_FILE" ]; then
    if [[ $(grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" /firehol/firehol.blocklist.cache | wc -l) -ge 1 ]] ; then
      # echo "Removing whitelisted IPs from the downloaded IP blacklist
      IPWHITELIST=`cat $LOCAL_WHITELIST_FILE`
      IPWHITELISTREGEX=""
      while IFS= read -r WHITELISTEDIP; do
        IPWHITELISTREGEX+="(${WHITELISTEDIP})|"
      done <<< ${IPWHITELIST}
      ## Clean the bounce variable (remove all line-breaks)
      IPWHITELISTREGEX="${IPWHITELISTREGEX//$'\n'/ }"
      IPWHITELISTREGEX=$(perl -pe "s/(.*)\|/\1/gms" <<< ${IPWHITELISTREGEX})
      grep -v -E ${IPWHITELISTREGEX} ${TMP_FILE} > ${WHITELIST_TMP_FILE} ## Remove all IPs listed in the whitelist file
      cp -f ${WHITELIST_TMP_FILE} ${TMP_FILE}
      rm -f ${WHITELIST_TMP_FILE}
    fi
  fi

  # Removing duplicate IPs from the list
  sort -o "$TMP_FILE" -u "$TMP_FILE" > /dev/null 2>&1

  mv -f "$TMP_FILE" "$CACHE_FILE"
}

update_iptables_ipset() {
  local TMP_FILE="$(mktemp)"
  
  IPs=$( iprange -C "$CACHE_FILE" )
  IPs=${IPs/*,/}
  
  iprange -1 "$CACHE_FILE" --print-prefix "add ${IPSET_TMP} " >"TMP_FILE" || exit 1
  echo -e "COMMIT" >> "$TMP_FILE"

  OPTS=
  if [ $IPs -gt 65536 ]; then
    OPTS="maxelem ${IPs}"
  fi

  if ! ipset_exists; then
    # create ipset
    ipset create "$IPSET" hash:ip $OPTS || exit 1
  fi

  # create a temporary ipset
  ipset create "$IPSET_TMP" hash:ip $OPTS || exit 1

  # flush the temporary ipset
  ipset flush "$IPSET_TMP" || exit 1

  # load the temporary ipset with the IPs in $TMP_FILE"
  ipset restore <"$TMP_FILE" || exit 1

  # swap the temporary ipset with the final one
  ipset swap "$IPSET_TMP" "$IPSET" || exit 1  
  
  # destroy the temporary ipset
  ipset destroy "$IPSET_TMP" 2>/dev/null
  rm -f $TMP_FILE

  if ! iptables_rule_exists; then
    create_iptables_rule
  fi
  }

download_rules
update_iptables_ipset
