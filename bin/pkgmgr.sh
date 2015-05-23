#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Pkgmgr is licenced under the GPLv3: http://gplv3.fsf.org

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` [operation] <parameter>"
            echo "operation:"
            echo "  -a, --add <name>         add a package"
            echo "  -A, --grp-add <name>     add group of packages"
            echo "  -b, --build <name>       build a package"
            echo "  -B, --grp-build <name>   build group of packages"
            echo "  -c, --conflict           show conflicting files"
            echo "  -d, --delete <name>      delete a package"
            echo "  -D, --grp-delete <name>  delete group of packages"
            echo "  -g, --group <name>       show group of packages"
            echo "  -i, --info <name>        show package information"
            echo "  -l, --list <name>        show package filelist"
            echo "  -o, --owner <path>       show the file ownership"
            echo "  -u, --update <name>      update a package"
            echo "  -U, --grp-update <name>  update group of packages"
            exit 0;;
        -a|--add) add $2; exit 0;;
        -A|--grp-add) grpadd $2; exit 0;;
        -b|--build) bld $2; exit 0;;
        -B|--grp-build) grpbld $2; exit 0;;
        -c|--conflict) con; exit 0;;
        -d|--delete) del $2; exit 0;;
        -D|--grp-delete) grpdel $2; exit 0;;
        -g|--group) grp $2; exit 0;;
        -i|--info) inf $2; exit 0;;
        -l|--list) lst $2; exit 0;;
        -o|--owner) own $2; exit 0;;
        -u|--update) upd $2; exit 0;;
        -U|--grp-update) grpupd $2; exit 0;;
    esac
done