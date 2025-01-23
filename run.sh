while :; do
    firehol-blocklists.sh
    sleep $(((((($RANDOM % 20)) + 50)) * 60)) # Sleeps for about 60 (+/- max 10) minutes (add random variable to avoid DDoS to iplist provider)
done
