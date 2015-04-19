#!/bin/bash -e

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Pkgmgr is licenced under the GPLv3: http://gplv3.fsf.org

root=/
inf=/pkg/info
lst=/pkg/list

PkgAdd() {
    echo "installing: $(basename ${name%.pkg*})"
    tar -C $root -xpf $name
}

PkgDel() {
    ign="--ignore-fail-on-non-empty"

    if [ -f $root/$inf/$name ]; then
        . $root/$inf/$name
    else
        echo "$name: info not found"; exit 1
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
}

ChkCon() {
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

ChkInf() {
    if [ -f $inf/$name ]; then
        . $inf/$name

        echo "program: $n"
        echo "version: $v"
        if [ -n "$u" ]; then
            echo "address: $u"
        fi
    else
        if [ -n "$name" ]; then
            echo "$name: info not found"
        fi
    fi
}

ChkLst() {
    if [ -n "$name" ]; then
        if [ -f $lst/$name ]; then
            cat $lst/$name
        else
            echo "$name: filelist not found"
        fi
    fi
}

ChkOwn() {
    if [ -n "$name" ]; then
        _own=$(grep $name $lst/*)
        for ln in $_own; do
            echo "${ln#$lst/}"
        done
    fi
}

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` [operation] <parameter>"
            echo "operation:"
            echo "  add <name> (root=) install package(s)"
            echo "  del <name>         delete the program files"
            echo "  con                show conflicting files"
            echo "  inf <name>         show program information"
            echo "  lst <name>         show program filelist"
            echo "  own <path>         show the file ownership"
            exit 0;;
        root=*)
            root=${i#*=};;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else o=$1; fi; name=$2

case "$o" in
    add) PkgAdd; exit 0;;
    del) PkgDel; exit 0;;
    con) ChkCon; exit 0;;
    inf) ChkInf; exit 0;;
    lst) ChkLst; exit 0;;
    own) ChkOwn; exit 0;;
esac