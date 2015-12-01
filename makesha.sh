#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Makesha is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

rcs_tempdir=$(mktemp -d)
sha_tempdir=$(mktemp -d)
pkg_repodir=/var/cache/pan/arc

print_green() {
    printf "\e[1m\e[32m>>>\e[0m $1\n"
}

print_red() {
    printf "\e[1m\e[31m>>>\e[0m $1\n"
}

AsRoot() {
    if [[ ${EUID} -ne 0 ]]; then
        print_red "This script must be run as root."; exit 1
    fi
}

GetRcs() {
    if [ -n $rcsrepo ]; then
        git clone $rcsrepo $rcs_tempdir
    else
        print_red "please set recipe repository in /etc/pan.conf"; exit 1
    fi
}

AsRoot; GetRcs

if [ -f $pkg_repodir/shasums.tar.xz ]; then
    rm -rf $pkg_repodir/shasums.tar.xz
fi

for _pkg in $(ls $rcs_tempdir); do
    if  [[ -L "$rcs_tempdir/$_pkg" && -d "$rcs_tempdir/$_pkg" ]]; then
        if [ -f $rcs_tempdir/$_pkg/recipe ]; then
            . $rcs_tempdir/$_pkg/recipe
            pkg=$_pkg
        fi
    elif [ -f $rcs_tempdir/$_pkg/recipe ]; then
        . $rcs_tempdir/$_pkg/recipe
    fi
    if  [ -f $pkg_repodir/$pkg-$ver-$rel.$ext ]; then
        shasum=$(echo "$(sha256sum $pkg_repodir/$pkg-$ver-$rel.$ext | cut -d' ' -f1) ")
        print_green "$pkg-$ver-$rel: $shasum"
        echo "sha=$shasum" > $sha_tempdir/$pkg-$ver-$rel
    fi
done

(cd $sha_tempdir; tar -cpJf $pkg_repodir/shasums.tar.xz ./)

rm -rf $rcs_tempdir $sha_tempdir
