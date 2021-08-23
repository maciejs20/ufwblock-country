## HOWTO

1. Add new chain to /etc/ufw/before.rules, named from-country
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

2. Add markers to *filter, just before COMMIT
```
#FROM-COUNTRY BLOCK BEGINS

#FROM-COUNTRY BLOCK ENDS
```