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

for _bin in add bld con del grp inf lst own upd pkgmgr; do
	install -v -Dm755 bin/${_bin}.sh $root/usr/bin/${_bin}
done

for _bin in add bld del upd; do
	install -v -Dm755 bin/grp${_bin}.sh $root/usr/bin/grp${_bin}
done

install -v -Dm644 conf/pkgmgr $root/etc/pkgmgr.conf
install -v -Dm644 sample/recipe $root/usr/share/pkgmgr/recipe