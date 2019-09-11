#!/bin/bash

verbose=false

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
    while read dnsbl; do
        if output="$(host -W 5 $reverse_ip.$dnsbl 8.8.8.8 2>&1 |
                     grep 'has address')"; then
            if [ -n "$output" ]; then
                echo "$host ($addr) is listed in $dnsbl"
                echo Lookup output:
                echo "$output"
                continue
            fi
        fi
        if $verbose; then
            echo "$host ($addr) is not listed in $dnsbl"
        fi
    done < /etc/dnsbls
done < /tmp/both.$$

rm -f /tmp/*.$$
