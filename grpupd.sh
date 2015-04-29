#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# GrpUpd is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` <grpdir> <arcdir>"
            exit 0;;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else grp=$1; arc=$2; fi;

for i in $(ls $grp); do
    upd $grp/$i/recipe $arc
done