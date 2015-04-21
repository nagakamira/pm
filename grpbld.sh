#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# GrpBld is licenced under the GPLv3: http://gplv3.fsf.org

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <grpdir>"
            exit 0;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else grp=$1; fi;

if [ ! -d $grp ]; then mkdir -p $grp; fi

for i in $(ls $grp); do
    if [ -f "$grp/$i/recipe" ]; then
        if [ ! -f /tmp/$(basename $grp).$i ]; then
            bld $grp/$i/recipe
            if [ $? -eq 0 ]; then
                touch /tmp/$(basename $grp).$i
            fi
        fi
    else
        echo "$grp/$i/recipe: info not found"
    fi
done