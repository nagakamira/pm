#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Con is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

out=/tmp/out.txt

cat $lst/* | sort -n | uniq -d > $out
for i in $(cat $out); do
    if [ ! -d "$i" ]; then
        _con=$(grep "$i" $lst/*)
        for ln in $_con; do
            echo "${ln#$lst/}"
        done
    fi
done