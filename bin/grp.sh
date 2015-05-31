#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Grp is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

lstgrp=false

Grp() {
    if [ ! -d $rcs ]; then git clone $gitrcs $rcs; fi

    for _pkg in $(ls $rcs); do
        if [ -f $rcs/$_pkg/recipe ]; then
            . $rcs/$_pkg/recipe
        fi
 
	   glst+=($s)
        if [ "$s" = "$name" ]; then plst+=($n); fi
    done

    if [ "$lstgrp" = true ]; then
	   glst=($(echo ${glst[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
        echo "${glst[@]}"
    else
	   plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
	   echo "${plst[@]}"
    fi
}

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage:"
            echo "  `basename $0` <group>   list all the packages of a group"
            echo "  `basename $0` lstgrp    list all the groups available"
            exit 0;;
        lstgrp)
            lstgrp=true;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else name=$1; Grp; fi