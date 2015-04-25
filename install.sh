#!/bin/bash

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: $0 (root=)"
            exit 0;;
        root=*)
            root=${i#*=};;
    esac
done

install -v -Dm755 add.sh $root/usr/bin/add
install -v -Dm755 bld.sh $root/usr/bin/bld
install -v -Dm755 del.sh $root/usr/bin/del
install -v -Dm755 grpadd.sh $root/usr/bin/grpadd
install -v -Dm755 grpbld.sh $root/usr/bin/grpbld
install -v -Dm755 grpdel.sh $root/usr/bin/grpdel
install -v -Dm755 pkgmgr.sh $root/usr/bin/pkgmgr
install -v -Dm755 imgmgr.sh $root/usr/bin/imgmgr
install -v -Dm644 bld.conf $root/etc/bld.conf
install -v -Dm644 pkgmgr.conf $root/etc/pkgmgr.conf