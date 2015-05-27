#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# GrpUpd is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <group>"
            exit 0;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else gn=$1; fi;

if [ ! -d $rcs ]; then git clone $gitrcs $rcs; fi

for _pkg in $(ls $rcs); do
    if [ -f $rcs/$_pkg/recipe ]; then
    	. $rcs/$_pkg/recipe
    fi
 
    if [ "$s" = "$gn" ]; then plst+=($n); fi
done

plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))

for _pkg in ${plst[@]}; do
    upd $_pkg
done