#!/bin/bash

verbose=false
list=/etc/dnsbls
badlist=/etc/dnsbls.bad
ignorelist=/etc/dnsbls.ignore
knownbad="$(cat $badlist 2>/dev/null || true)"
ignored="$(cat $ignorelist 2>/dev/null || true)"
detected=""

set -o pipefail

PERL_ADDR_TO_QUERY='
use English;

while (<>) {
    chomp;
    if (/:/) {
        if (/::/) {
            $before = $PREMATCH;
            $after = $POSTMATCH;
        }
        else {
            $before = $_;
            $after = "";
        }
        @before = split(/:/, $before);
        @after = split(/:/, $after);
        while (@before + @after < 8) {
            push(@before, "0");
        }
        for (reverse(@before, @after)) {
            push(@numbers, reverse(split(//, sprintf("%04x", hex($_)))));
        }
    }
    else {
        @numbers = reverse(split(/\./, $_));
    }
    print(join(".", @numbers), "\n");
}
'

addrtoquery() {
    echo "$1" | perl -e "$PERL_ADDR_TO_QUERY"
}

host=$(hostname --fqdn)

host $host 8.8.8.8 | awk '/ has .*address/ {print $NF}' | sort >| /tmp/resolved.$$
(curl --silent -4 http://ifconfig.co; curl --silent -6 http://ifconfig.co) | sort >| /tmp/ifconfig.$$
comm -12 /tmp/resolved.$$ /tmp/ifconfig.$$ >| /tmp/both.$$

while read addr; do
    reverse_ip=`addrtoquery "$addr"`
    while read dnsbl ok_results; do
        if [[ "$ignored" =~ $dnsbl ]]; then
            continue
        fi
        # 127.255 is for DNSBL errors, not listings
	if (! host -W 5 $reverse_ip.$dnsbl 8.8.8.8 >| /tmp/host.$$ 2>&1 ||
		grep -q -s 'has address 127\.255' /tmp/host.$$) &&
	       # The query may have failed because the DNSBL doesn't allow
	       # querying through 8.8.8.8, so fall back on querying through the
	       # local nameserver. Depending on the TTL on the record this
	       # might cause us to think we're listed for longer than we
	       # actually are, but that is worth the cost for the sake of
	       # being able to detect the listing.
	       (! host -W 5 $reverse_ip.$dnsbl >| /tmp/host.$$ 2>&1 ||
		    grep -q -s 'has address 127\.255' /tmp/host.$$); then
	    if ! grep -q -s -w NXDOMAIN /tmp/host.$$; then
		if $verbose; then
		    echo "Error looking up $addr in $dnsbl:" 1>&2
		    cat /tmp/host.$$ 1>&2
		fi
		continue
	    fi
        elif output="$(grep 'has address' /tmp/host.$$)"; then
	    if [ -n "$ok_results" ]; then
		dnsbl_addr="$(echo "$output" | awk 'NR==1{print $NF}')"
		for ok_addr in $ok_results; do
		    if [ "$ok_addr" = "$dnsbl_addr" ]; then
			output=""
			break
		    fi
		done
                if [ -z "$output" ]; then
                    continue
                fi
	    fi
	    detected="$detected $dnsbl"
	    if [[ ! "$knownbad" =~ $dnsbl ]]; then
		echo "$host ($addr) is listed in $dnsbl"
		echo Lookup output:
		echo "$output"
		continue
	    fi
        fi
        if $verbose; then
            echo "$host ($addr) is not listed in $dnsbl"
        fi
    done < $list
done < /tmp/both.$$

for dnsbl in $knownbad; do
    if [[ ! "$detected" =~ $dnsbl ]]; then
        echo "$dnsbl is in $badlist but we are not currently listed there"
    fi
done

rm -f /tmp/*.$$
