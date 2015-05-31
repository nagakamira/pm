#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Inf is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

Inf() {
    if [ -f $inf/$name ]; then
        . $inf/$name

        echo "program: $n"
        echo "version: $v"
        echo "section: $s"
        echo "depends: ${d[@]}"
        if [ -n "$u" ]; then
            echo "address: $u"
        fi
    else
        if [ -n "$name" ]; then
            echo "$name: info not found"
        fi
    fi
}

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <name>"
            exit 0;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else name=$1; Inf; fi