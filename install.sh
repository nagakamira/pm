#!/bin/bash

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: $0 (rootdir=)"
            exit 0;;
        rootdir=*)
            rootdir=${i#*=};;
    esac
done

if [ ! -d $rootdir/var/cache/pan/arc ]; then
    mkdir -p $rootdir/var/cache/pan/arc
fi

if [ ! -d $rootdir/var/lib/pan ]; then
    mkdir -p $rootdir/var/lib/pan
fi

install -v -Dm755 pan.sh $rootdir/usr/bin/pan
install -v -Dm755 makepkg.sh $rootdir/usr/bin/makepkg
install -v -Dm644 pan.conf $rootdir/etc/pan.conf
install -v -Dm644 sample/recipe $rootdir/usr/share/pan/recipe
install -v -Dm644 sample/system $rootdir/usr/share/pan/system