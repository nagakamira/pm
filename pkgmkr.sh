#!/bin/bash -e

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Pkgmkr is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmkr

src=$HOME/build/src
pkg=$HOME/build/pkg
arc=$HOME/build/arc

case "$1" in
    -h|--help)
        echo "usage: `basename $0` <recipe>"
        exit 0;;
esac

if [ -z "$1" ]; then $0 -h; exit 0; fi

mkdir -p $arc $par $pkg $src

if [ ! -f "$1" ]; then
    echo "recipe not found"; exit 1
else
    . $1; if [ -z "$p" ]; then p=$n-$v; fi
fi

if [ -n "$u" ]; then
    file=$(basename $u)

    if [ ! -f $arc/$file ]; then
        echo "downloading: $file"
        curl -L -o $arc/$file $u
    fi

    echo "extracting: $file"
    if [ "${file##*.}" = "zip" ]; then
        unzip -d $src $arc/$file
    else
        tar -C $src -xpf $arc/$file
    fi
else
    p=./
fi

echo "building: $n-$v"
cd $src/$p; pkg=$pkg/$p; build
cd $pkg; mkdir -p $pkg/{$inf,$lst}

echo "n=$n" >> $pkg/$inf/$n
echo "v=$v" >> $pkg/$inf/$n
echo "u=$u" >> $pkg/$inf/$n
find -L ./ | sed 's/.\//\//' | sort > $pkg/$lst/$n
tar -cpJf $arc/$n-$v.$pkgext ./; #rm -rf $pkg $src