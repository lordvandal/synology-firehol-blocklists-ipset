# ipset iptables Firehol blocklists (level1-2-3) pull-and-load script for Synology DSM 7.2 cron
A shell script that grabs the latest Firehol blocklists and adds it to iptables via ipset.
Additional blocklists can easily be added by popping their download URLs into the script.
By default it's loading the level 1, 2 and 3 lists - which means you should pull-and-load frequently: https://iplists.firehol.org/

#### Important technical information
Synology has the ipset module in the kernel, but of the two methods only for hash:ip, without hash:net. Additionally, there is no ipset command in Synology DSM.
The solution to this is a Docker container, which
  - contains the ipset command
  - has access to the host network, to execute it and add the lists to the host iptables
  - convert all blocklists from .netset (hash:net) format to .ipset (hash:ip) format

## Usage
Install the `firehol-blocklists` script somewhere sensible (i.e. `/usr/local/sbin`).  Make sure you've read the script, and are happy with what it does.
Then install a `cronjob` to run the script periodically (personally, I run it on startup and every hour).
For example, create an executable script named `/etc/cron.daily/firehol-blocklists`:
```
#!/bin/sh
/usr/local/sbin/firehol-blocklists -u
```
Configurations reside by default in `/etc/firehol-blocklists`, consisting of `whitelist` and `blacklist`; tailor them to your need.
By default private IP ranges are whitelisted, as they appear in the Firehol blocklists.

### Important warning
This script **by design** downloads lists of IP ranges from a 3rd party source (firehol) and adds `DROP` instructions to your iptables firewall.
Just stop and think for a moment - the consequences of this may be dire.  Be certain you trust the sources and be certain you're downloading them securely (i.e. over HTTPS, at a minimum).

## Optional arguments
You may wish to apply some "value overrides" to the script, or delete the iptables chain it installs, or separate downloading the latest blocklist from applying them (perhaps to perform your own sanity checks, or to add additional records):

```
  -u                   Download blocklists and update iptables, falling back to cache file unless -s is specified
  -c=CHAIN_NAME        Override default iptables chain name
  -l=URL_LIST          Override default block list URLs [careful!]
  -f=CACHE_FILE_PATH   Override default cache file path
  -m=LOCAL_BLOCKLIST   Override default local block list file
  -w=WHITELIST         Override default white list file
  -s                   Skip failed blocklist downloads, continuing instead of aborting
  -z                   Update the blocklist from the local cache, don't download new entries
  -d                   Delete the iptables chain (removing all blocklists)
  -o                   Only download the blocklists, don't update iptables
  -t                   Enable logging of blocklist hits in iptables
  -h                   Display this help message

```

## Credits
Based on the spamhaus-drop script by wallyhall, improved and tailored for Synology DSM 7.2<br>
Credit: [Matthew Hall](https://github.com/wallyhall)<br>
Original repository: https://github.com/wallyhall/spamhaus-drop

Improvements: [lordvandal](https://github.com/lordvandal)<br>
Repository: https://github.com/lordvandal/dock-privoxy
