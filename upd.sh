#!/bin/bash -e

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Upd is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <name>"
            exit 0;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else pn=$1; fi;

if [ -f $rcs/$pn/recipe ]; then
    . $rcs/$pn/recipe; v1=$v; v=
elif [ ! -d $rcs ]; then
    git clone $gitrcs $rcs
    . $rcs/$pn/recipe; v1=$v; v=
else
    echo "$pn: recipe: file not found"; exit 1
fi

if [ -f $inf/$n ]; then
    . $inf/$n; v2=$v; v=
else
    echo "$n: info: file not found"; exit 1
fi

v=$(echo -e "$v1\n$v2" | sort -V | tail -n1)

if [ "$v1" != "$v2" ]; then
    if [ "$v1" = "$v" ]; then
        echo "updating: $n ($v2 -> $v1)"

        if [ -f "$sys/$n" ]; then . $sys/$n
            if type upd_ >/dev/null 2>&1; then upd_; fi
        fi

        rn=$lst/$n; cp $rn $rn.bak

        if [ -f $arc/$n-$v.$pkgext ]; then
            tar -C $root -xpf $arc/$n-$v.$pkgext
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

        if [ -f "$sys/$n" ]; then . $sys/$n
            if type _upd >/dev/null 2>&1; then _upd; fi
        fi

        if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [UPD] $n ($v)" >> $log/upd
    fi
fi