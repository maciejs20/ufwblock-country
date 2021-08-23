## THE PURPOSE

This is a small script that limits access to selected country, all other are blocked. It works for all ports You specify in it's config.
It downloads country's IP ADDR list, adds local IPs and creates iptables entries in from-country chain by altering /etc/ufw/before.rules.

Script depends on http://www.ipdeny.com/ipblocks/data/counties. It contains basis checks for list sanity, so typical errors will be discarded.

It works (and blocks) only TCP ports.

Please note that this is NOT production-ready, it's just a dirty hack...


## HOWTO

### Verify configuration

There are following settings available in the script:


* URL="http://www.ipdeny.com/ipblocks/data/countries/pl.zone"

URL for the country's IP

* PORTS="12345 22"

Tcp ports to block, separated by commas

* ALWAYS_ALLOWED="192.168.0.0/16 10.10.1.0/16"

Local IP's that are always allowed

* MIN_RULES=1000

Sanity check for IP list downloaded from $URL - if there are less IP's than specified, the script will exit with no modifications to rules.

### Create chain
Add new chain:

```
:from-country - [0:0]
```
 to /etc/ufw/before.rules *filter chains section.
Whole block should look like:

```
# Don't delete these required lines, otherwise there will be errors
*filter
:ufw-before-input - [0:0]
:ufw-before-output - [0:0]
:ufw-before-forward - [0:0]
:ufw-not-local - [0:0]
:from-country - [0:0]
# End required lines
```

### Add markers
Add markers below to *filter, just before COMMIT. Those lines will be replaced with actual rules.
```
#FROM-COUNTRY BLOCK BEGINS

#FROM-COUNTRY BLOCK ENDS
```

example entries (may not match Your setup, use as reference only):
```
#
# ufw-not-local
#
-A ufw-before-input -j ufw-not-local

# if LOCAL, RETURN
-A ufw-not-local -m addrtype --dst-type LOCAL -j RETURN

# if MULTICAST, RETURN
-A ufw-not-local -m addrtype --dst-type MULTICAST -j RETURN

# if BROADCAST, RETURN
-A ufw-not-local -m addrtype --dst-type BROADCAST -j RETURN

# all other non-local packets are dropped
-A ufw-not-local -m limit --limit 3/min --limit-burst 10 -j ufw-logging-deny
-A ufw-not-local -j DROP

# allow MULTICAST mDNS for service discovery (be sure the MULTICAST line above
# is uncommented)
-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT

# allow MULTICAST UPnP for service discovery (be sure the MULTICAST line above
# is uncommented)
-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT

#FROM-COUNTRY BLOCK BEGINS
#FROM-COUNTRY BLOCK ENDS

# don't delete the 'COMMIT' line or these rules won't be processed
COMMIT
```

### Add to root's cron
Add this script to crontab and pray it works properly.
Remember to add all required PATH locations as well as recipient for mails with error messages.

```
PATH=/bin:/usr/bin:/usr/sbin
MAILTO=myname
30 3 * * * /root/bin/ufw/ufwblock-country/ufwblock-start.sh
```