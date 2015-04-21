#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Del is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <name> (root=)"
            exit 0;;
        root=*)
            root=${i#*=};;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else name=$1; fi;

ign="--ignore-fail-on-non-empty"

if [ -f $root/$inf/$name ]; then
    . $root/$inf/$name
else
    echo "$name: info not found"; exit 1
fi

if [ -f "$root/$sys/$name" ]; then . $root/$sys/$name
    if type del_ >/dev/null 2>&1; then del_; fi
fi

if [ -f "$root/$lst/$name" ]; then
    echo "removing: $name-$v"
    list=$(tac $root/$lst/$name)
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

if type _del >/dev/null 2>&1; then _del; fi

if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [DEL] $n ($v)" >> $root/$log/del