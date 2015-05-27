#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Add is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

grpsys=false
nodeps=false

rdeps() {
    if [ -f $rcs/$1/recipe ]; then
        . $rcs/$1/recipe
    fi

    deps=(${deps[@]} $1)
    for dep in ${d[@]}; do
        if [[ ${deps[*]} =~ $dep ]]; then
            continue
        else
            deps=(${deps[@]} $dep)
            rdeps $dep
        fi
    done
}

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage:"
            echo "  `basename $0` <name> (root=)         add a package"
            echo "  `basename $0` <name> nodeps (root=)  skip dependencies"
            exit 0;;
        grpsys)
            grpsys=true;;
        nodeps)
            nodeps=true;;
        root=*)
            root=${i#*=};;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else pn=$1; fi;

if [ -f $rcs/$pn/recipe ]; then
    . $rcs/$pn/recipe
elif [ ! -d $rcs ]; then
    git clone $gitrcs $rcs
    . $rcs/$pn/recipe
else
    echo "$pn: recipe: file not found"; exit 1
fi

rdeps $pn
deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))

if [ "$nodeps" = true ]; then deps=($pn); fi

for dep in ${deps[@]}; do
    if [ ! -f $rcs/$dep/recipe ]; then
        mdeps+=($dep); echo "$dep: recipe: file not found"
    else
        . $rcs/$dep/recipe; export n v
        if [ -f "$root/$inf/$n" ]; then
            continue
        else
    	   _deps+=($n)
        fi
    fi
done

if [ "${#mdeps[@]}" -ge "1" ]; then
    echo "missing deps: ${mdeps[@]}"; exit 1
fi

if [ "${#_deps[@]}" -le "0" ]; then _deps=($pn); fi

echo "total package(s): ${_deps[@]}"

for dep in ${_deps[@]}; do
    . $rcs/$dep/recipe;
    if [ ! -f $arc/$n-$v.$pkgext ]; then
        echo "$n-$v.$pkgext: file not found"
        _pkg+=($n)
    fi
done

if [ "${#_pkg[@]}" -ge "1" ]; then
    echo "missing archive(s): ${_pkg[@]}"; exit 1
fi

for dep in ${_deps[@]}; do
    . $rcs/$dep/recipe; export n v
    echo "installing: $n ($v)"
    tar -C $root -xpf $arc/$n-$v.$pkgext
    chmod 777 $root/pkg &>/dev/null

    if [ "$grpsys" = false ]; then
        if [ -f "$root/$sys/$n" ]; then . $root/$sys/$n
            if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
                ". $sys/$n; if type _add >/dev/null 2>&1; then _add; fi"
            else
                if type _add >/dev/null 2>&1; then _add; fi
            fi
        fi
    fi

    if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
    echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [ADD] $n ($v)" >> $root/$log/add
done