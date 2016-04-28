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

if [ ! -d $rootdir/var/cache/pm/arc ]; then
    mkdir -p $rootdir/var/cache/pm/arc
fi

if [ ! -d $rootdir/var/lib/pm ]; then
    mkdir -p $rootdir/var/lib/pm
fi

install -v -Dm755 pm.sh $rootdir/usr/bin/pm
install -v -Dm755 pmake.sh $rootdir/usr/bin/pmake
install -v -Dm644 pm.conf $rootdir/etc/pm.conf
install -v -Dm644 README.md $rootdir/usr/share/pm/README.md
install -v -Dm644 proto/recipe $rootdir/usr/share/pm/proto/recipe
install -v -Dm644 proto/system $rootdir/usr/share/pm/proto/system
install -v -Dm644 sample/recipe $rootdir/usr/share/pm/sample/recipe
install -v -Dm644 sample/system $rootdir/usr/share/pm/sample/system
