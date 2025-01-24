#/bin/bash

if [[ ! -e /firehol/firehol.blocklist.cache ]]; then
  cp /firehol-template/firehol.blocklist.cache /firehol
fi

if [[ ! -e /firehol/blocklist. ]]; then
  cp /firehol-template/blocklist /firehol
fi

if [[ ! -e /firehol/whitelist ]]; then
  cp /firehol-template/whitelist /firehol
fi

while :; do
    firehol-blocklists.sh
    sleep $(((((($RANDOM % 20)) + 50)) * 60)) # Sleeps for about 60 (+/- max 10) minutes (add random variable to avoid DDoS to iplist provider)
done
