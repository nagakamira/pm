#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Upd is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <recipe> <arcdir>"
            exit 0;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else rcs=$1; arc=$2; fi;

. $rcs; pn=$n; v1=$v; v=
. $inf/$pn; v2=$v; v=
v=$(echo -e "$v1\n$v2" | sort -V | tail -n1)

if [ "$v1" != "$v2" ]; then
    if [ "$v1" = "$v" ]; then
        echo "updating: $pn ($v2 -> $v1)"

        if [ -f "$sys/$pn" ]; then . $sys/$pn
            if type upd_ >/dev/null 2>&1; then upd_; fi
        fi

        rn=$lst/$pn; cp $rn $rn.bak

        if [ -f $arc/$pn-$v.pkg.tar.xz ]; then
            tar -C $root -xpf $arc/$pn-$v.pkg.tar.xz
        fi

        list=$(comm -23 <(sort $rn.bak) <(sort $rn))

        ign="--ignore-fail-on-non-empty"
        for l in $list; do
            if [ -L $l ]; then unlink $l
            elif [ -f $l ]; then rm -f $l
            elif [ "$l" = "/" ]; then continue
            elif [ -d $l ]; then rmdir $ign $l
            fi
        done

        rm $rn.bak

        if [ -f "$sys/$pn" ]; then . $sys/$pn
            if type _upd >/dev/null 2>&1; then _upd; fi
        fi

        if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [UPD] $pn ($v)" >> $log/upd
    fi
fi