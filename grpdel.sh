#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# GrpDel is licenced under the GPLv3: http://gplv3.fsf.org

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

for _pkg in $(ls $root/$inf); do
    if [ -f $root/$inf/$_pkg ]; then
    . $root/$inf/$_pkg; echo $n $v
    fi
 
    if [ "$s" = "$gn" ]; then plst+=($n); fi
done

plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))

for _pkg in ${plst[@]}; do
    if [ -f "$root/$sys/$_pkg" ]; then
        . $root/$sys/$_pkg; . $root/$inf/$_pkg; export n v
        cp $root/$inf/$_pkg $root/$inf/$_pkg.inf
        cp $root/$sys/$_pkg $root/$sys/$_pkg.sys
        if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
            ". $sys/$_pkg; if type del_ >/dev/null 2>&1; then del_; fi"
        else
            if type del_ >/dev/null 2>&1; then del_; fi
        fi
    fi

done

for _pkg in ${plst[@]}; do
    del $_pkg root=$root grpsys
done

for _pkg in ${plst[@]}; do
    if [ -f "$root/$sys/$_pkg.sys" ]; then
        . $root/$sys/$_pkg.sys; . $root/$inf/$_pkg.inf; export n v
        if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
            ". $sys/$_pkg.sys; if type _del >/dev/null 2>&1; then _del; fi"
        else
            if type _del >/dev/null 2>&1; then _del; fi
        fi
        rm -f $root/$sys/$_pkg.sys $root/$inf/$_pkg.inf
    fi

done