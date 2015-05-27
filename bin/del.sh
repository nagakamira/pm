#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Del is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

grpsys=false

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <name> (root=)"
            exit 0;;
        grpsys)
            grpsys=true;;
        root=*)
            root=${i#*=};;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else name=$1; fi;

ign="--ignore-fail-on-non-empty"

if [ -f $root/$inf/$name ]; then
    . $root/$inf/$name; export n v
else
    echo "$name: info: file not found"; exit 1
fi

if [ "$grpsys" = false ]; then
    if [ -f "$root/$sys/$n" ]; then
        . $root/$sys/$n
        if type _del >/dev/null 2>&1; then export -f _del; fi
        if type _add >/dev/null 2>&1; then export -f _add; fi
        if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
            ". $sys/$n; if type del_ >/dev/null 2>&1; then del_; fi"
        else
            if type del_ >/dev/null 2>&1; then del_; fi
        fi

    fi
fi

if [ -f "$root/$lst/$n" ]; then
    echo "removing: $n ($v)"
    list=$(tac $root/$lst/$n)
else
    continue
fi

for l in $list; do
    if [ -L $root/$l ]; then unlink $root/$l
    elif [ -f $root/$l ]; then rm -f $root/$l
    elif [ "$l" = "/" ]; then continue
    elif [ -d $root/$l ]; then rmdir $ign $root/$l
    fi
done

if [ "$grpsys" = false ]; then
    if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
        "if type _del >/dev/null 2>&1; then _del; fi"
    else
        if type _del >/dev/null 2>&1; then _del; fi
    fi
fi

if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [DEL] $n ($v)" >> $root/$log/del