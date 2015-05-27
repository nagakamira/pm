#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Own is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <path>"
            exit 0;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else path=$1; fi;

if [ -n "$path" ]; then
    _own=$(grep $path $lst/*)
    for ln in $_own; do
        echo "${ln#$lst/}"
    done
fi