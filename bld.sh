#!/bin/bash -e

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Bld is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pkgmgr.conf

download() {
    if [ ! "${_url%://*}" = "git" ]; then
        file=$(basename $1)
        if [ ! -f $arc/$file ]; then
            echo "downloading: $file"
            curl -L -o $arc/$file $1
        fi
    fi
}

extract() {
    if [ ! "${_url%://*}" = "git" ]; then
        if [ -z "$e" ]; then
            echo "extracting: $file"
            if [ "${file##*.}" = "zip" ]; then
                unzip -d $src $arc/$file
            else
                tar -C $src -xpf $arc/$file
            fi
        fi
    fi
}

case "$1" in
    -h|--help)
        echo "usage: `basename $0` <name>"
        exit 0;;
esac

if [ -z "$1" ]; then $0 -h; exit 0; else pn=$1; fi;

if [ -f $rcs/$pn/recipe ]; then
    cp $rcs/$pn/recipe /tmp/$pn.recipe
    sed -i -e "s#build() {#build() {\n    set -e#" /tmp/$pn.recipe
    . /tmp/$pn.recipe
elif [ ! -d $rcs ]; then
    git clone $gitrcs $rcs
    cp $rcs/$pn/recipe /tmp/$pn.recipe
    sed -i -e "s#build() {#build() {\n    set -e#" /tmp/$pn.recipe
    . /tmp/$pn.recipe
else
    echo "$pn: recipe: file not found"; exit
fi

if [ -z "$p" ]; then p=$n-$v; fi

rcs=$rcs/$n; _pkg=$pkg; pkg=$pkg/$n
mkdir -p $arc $pkg $src

if [ -n "$u" ]; then _url=$u
    if [ "${#u[@]}" -gt "1" ]; then
        for _u in "${u[@]}"; do
            download $_u
            extract
        done
    else
        download $u
        extract
    fi
else
    p=./
fi

echo "building: $n-$v"
if [ -d "$src/$p" ]; then cd $src/$p; else cd $src; fi

export CHOST CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS arc pkg rcs src n v u p
export -f build; fakeroot -s $src/state build

if [ -f "$rcs/system" ]; then
    mkdir -p $pkg/$sys; cp $rcs/system $pkg/$sys/$n
fi

cd $pkg; mkdir -p $pkg/{$inf,$lst}
echo "n=$n" >> $pkg/$inf/$n
echo "v=$v" >> $pkg/$inf/$n
echo "s=$s" >> $pkg/$inf/$n
printf "%s " "d=(${d[@]})" >> $pkg/$inf/$n
echo -e "" >> $pkg/$inf/$n
echo "u=$u" >> $pkg/$inf/$n
find -L ./ | sed 's/.\//\//' | sort > $pkg/$lst/$n

fakeroot -i $src/state -- tar -cpJf $arc/$n-$v.$pkgext ./
rm -rf $src/state $_pkg $src /tmp/$n.recipe