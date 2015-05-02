#!/bin/bash -e

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Pkgmgr is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

PkgCon() {
    out=/tmp/out.txt
    cat $lst/* | sort -n | uniq -d > $out
    for i in $(cat $out); do
        if [ ! -d "$i" ]; then
            _con=$(grep "$i" $lst/*)
            for ln in $_con; do
                echo "${ln#$lst/}"
            done
        fi
    done
}

PkgInf() {
    if [ -f $inf/$name ]; then
        . $inf/$name

        echo "program: $n"
        echo "version: $v"
        echo "section: $s"
        echo "depends: ${d[@]}"
        if [ -n "$u" ]; then
            echo "address: $u"
        fi
    else
        if [ -n "$name" ]; then
            echo "$name: info not found"
        fi
    fi
}

PkgLst() {
    if [ -n "$name" ]; then
        if [ -f $lst/$name ]; then
            cat $lst/$name
        else
            echo "$name: filelist not found"
        fi
    fi
}

PkgOwn() {
    if [ -n "$name" ]; then
        _own=$(grep $name $lst/*)
        for ln in $_own; do
            echo "${ln#$lst/}"
        done
    fi
}

GrpLst() {
    plst()
    for _pkg in $(ls $inf); do
        if [ -f $inf/$_pkg ]; then
            . $inf/$_pkg
        fi
        if [ "$s" = "$name" ]; then plst+=($n); fi
    done
    plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
    echo "${plst[@]}"
}

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` [operation] <parameter>"
            echo "operation:"
            echo "  con                show conflicting files"
            echo "  inf <name>         show program information"
            echo "  lst <name>         show program filelist"
            echo "  own <path>         show the file ownership"
            echo "  grp <name>         show group of packages"
            exit 0;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else o=$1; fi; name=$2

case "$o" in
    con) PkgCon; exit 0;;
    inf) PkgInf; exit 0;;
    lst) PkgLst; exit 0;;
    own) PkgOwn; exit 0;;
    grp) GrpLst; exit 0;;
esac