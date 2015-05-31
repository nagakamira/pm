#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Lst is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

Lst() {
    if [ -n "$name" ]; then
        if [ -f $lst/$name ]; then
            cat $lst/$name
        else
            echo "$name: filelist not found"
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

if [ -z "$1" ]; then $0 -h; exit 0; else name=$1; Lst; fi