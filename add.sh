#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Add is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

grpsys=false

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <file> (root=)"
            exit 0;;
        grpsys)
            grpsys=true;;
        root=*)
            root=${i#*=};;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else file=$1; fi;

echo "installing: $(basename ${file%.pkg*})"
tar -C $root -xpf $file

if [ "$grpsys" = false ]; then
    pn=$(basename ${file%-*}); . $root/$inf/$pn; export n v
    if [ -f "$root/$sys/$pn" ]; then . $root/$sys/$pn
        if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
            ". $sys/$pn; if type _add >/dev/null 2>&1; then _add; fi"
        else
            if type _add >/dev/null 2>&1; then _add; fi
        fi
    fi
fi

if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [ADD] $pn ($v)" >> $root/$log/add