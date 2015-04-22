#!/bin/bash -e

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Bld is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/bld.conf
. /etc/pkgmgr.conf

src=$HOME/build/src
pkg=$HOME/build/pkg
arc=$HOME/build/arc

download() {
    file=$(basename $1)
    if [ ! -f $arc/$file ]; then
        echo "downloading: $file"
        curl -L -o $arc/$file $1
    fi
}

extract() {
    echo "extracting: $file"
    if [ "${file##*.}" = "zip" ]; then
        unzip -d $src $arc/$file
    else
        tar -C $src -xpf $arc/$file
    fi    
}

case "$1" in
    -h|--help)
        echo "usage: `basename $0` <recipe>"
        exit 0;;
esac

if [ -z "$1" ]; then $0 -h; exit 0; fi

. $1; if [ -z "$p" ]; then p=$n-$v; fi
_rcs=$(dirname $1); cd $_rcs; rcs=`pwd`

mkdir -p $arc $pkg $src

if [ -n "$u" ]; then
    if [ "${#u[@]}" -gt "1" ]; then
        for _u in "${u[@]}"; do
            download $_u
            if [ -z "$e" ]; then
                extract
            fi
        done
    else
        download $u
        extract
    fi
else
    p=./
fi

echo "building: $n-$v"
cd $src/$p; pkg=$pkg/$n

export CHOST CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS arc pkg rcs src n v p
export -f build; fakeroot -s $src/state build

if [ -f "$rcs/system" ]; then
    mkdir -p $pkg/$sys; cp $rcs/system $pkg/$sys/$n
fi

cd $pkg; mkdir -p $pkg/{$inf,$lst}
echo "n=$n" >> $pkg/$inf/$n
echo "v=$v" >> $pkg/$inf/$n
echo "u=$u" >> $pkg/$inf/$n
find -L ./ | sed 's/.\//\//' | sort > $pkg/$lst/$n

fakeroot -i $src/state -- tar -cpJf $arc/$n-$v.pkg.tar.xz ./
rm -rf $src/state $pkg $src