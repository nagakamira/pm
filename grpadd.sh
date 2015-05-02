#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# GrpAdd is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

plst=()

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <group> (root=)"
            exit 0;;
        root=*)
            root=${i#*=};;
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
    . $rcs/$_pkg/recipe
    add $n root=$root grpsys
done

for _pkg in ${plst[@]}; do
    . $rcs/$_pkg/recipe; export n v
    if [ -f "$root/$sys/$n" ]; then . $root/$sys/$n
        if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
            ". $sys/$n; if type _add >/dev/null 2>&1; then _add; fi"
        else
            if type _add >/dev/null 2>&1; then _add; fi
        fi
    fi
done