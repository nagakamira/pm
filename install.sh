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

for _bin in add bld del pan upd; do
	install -v -Dm755 ${_bin}.sh $root/usr/bin/${_bin}
done

install -v -Dm644 pan.conf $root/etc/pan.conf
install -v -Dm644 sample/recipe $root/usr/share/pan/recipe