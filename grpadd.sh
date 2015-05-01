#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# GrpAdd is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <grpdir> <arcdir> (root=)"
            exit 0;;
        root=*)
            root=${i#*=};;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else grp=$1; arc=$2; fi;

for i in $(ls $grp); do
    . $grp/$i/recipe; export n v
    if [ -f "$arc/$n-$v.pkg.tar.xz" ]; then
        add $arc/$n-$v.pkg.tar.xz root=$root grpsys
    else
        echo "$arc/$n-$v.pkg.tar.xz: file not found"
    fi
done

for pn in $(ls $grp); do
    . $grp/$pn/recipe; export n v
    if [ -f "$root/$sys/$pn" ]; then . $root/$sys/$pn
        if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
            ". $sys/$pn; if type _add >/dev/null 2>&1; then _add; fi"
        else
            if type _add >/dev/null 2>&1; then _add; fi
        fi
    fi
done