#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# GrpAdd is licenced under the GPLv3: http://gplv3.fsf.org

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
    . $grp/$i/recipe
    if [ -f "$arc/$n-$v.pkg.tar.xz" ]; then
        add $arc/$n-$v.pkg.tar.xz root=$root
    else
        echo "$arc/$n-$v.pkg.tar.xz: file not found"
    fi
done