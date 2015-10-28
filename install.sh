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

if [ ! -d $root/pkg/arc ]; then
    mkdir -p $root/pkg/arc
fi
chmod 777 $root/pkg/{,arc}

install -v -Dm755 pan.sh $root/usr/bin/pan
install -v -Dm755 makepkg.sh $root/usr/bin/makepkg
install -v -Dm644 pan.conf $root/etc/pan.conf
install -v -Dm644 sample/recipe $root/usr/share/pan/recipe