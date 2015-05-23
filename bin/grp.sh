#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Grp is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <name>"
            exit 0;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else name=$1; fi;

if [ ! -d $rcs ]; then git clone $gitrcs $rcs; fi

for _pkg in $(ls $rcs); do
    if [ -f $rcs/$_pkg/recipe ]; then
            . $rcs/$_pkg/recipe
    fi
 
    if [ "$s" = "$name" ]; then plst+=($n); fi
done

plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
echo "${plst[@]}"