#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# GrpDel is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <grpdir> (root=)"
            exit 0;;
        root=*)
            root=${i#*=};;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else grp=$1; fi;

for pn in $(ls $grp); do
    if [ -f "$root/$sys/$pn" ]; then
        . $root/$sys/$pn; . $root/$inf/$pn; export n v
        cp $root/$inf/$pn $root/$inf/$pn.inf
        cp $root/$sys/$pn $root/$sys/$pn.sys
        if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
            ". $sys/$pn; if type del_ >/dev/null 2>&1; then del_; fi"
        else
            if type del_ >/dev/null 2>&1; then del_; fi
        fi
    fi

done

for i in $(ls $grp); do
    if [ -f "$root/$inf/$i" ]; then
        del $i root=$root grpsys
    else
        echo "$i: info not found"
    fi
done

for pn in $(ls $grp); do
    if [ -f "$root/$sys/$pn.sys" ]; then
        . $root/$sys/$pn.sys; . $root/$inf/$pn.inf; export n v
        if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
            ". $sys/$pn.sys; if type _del >/dev/null 2>&1; then _del; fi"
        else
            if type _del >/dev/null 2>&1; then _del; fi
        fi
        rm -f $root/$sys/$pn.sys $root/$inf/$pn.inf
    fi

done