#!/bin/bash
#   Copyright (c) 2015 Ali H. Caliskan <ali.h.caliskan@gmail.com>
#   Copyright (c) 2009-2015 Pacman Development Team <pacman-dev@archlinux.org>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

INFAKEROOT=0

source_safe() {
    if ! source "$1"; then
        printf "$(gettext "Failed to source %s \n")" "$1"
        exit 1
    fi
}

get_recipes() {
    if [ ! -d $rcs ]; then
        git clone $gitrcs $rcs
        chgrp -R users $rcs
        chmod -R g+w $rcs
    fi
}

check_option() {
    local needle=$1; shift
    local options=$@

    for opt in ${options[@]}; do
        if [[ $opt = "$needle" ]]; then
            # enabled
            return 0
        elif [[ $opt = "!$needle" ]]; then
            # disabled
            return 1
        fi
    done

    # not found
    return 127
}

assert_option() {
    check_option "$1" ${o[@]}
    case $? in
        0) # assert enabled
            [[ $2 = y ]]
            return ;;
        1) # assert disabled
            [[ $2 = n ]]
            return
    esac

    check_option "$1" ${OPTIONS[@]}
    case $? in
        0) # assert enabled
            [[ $2 = y ]]
            return ;;
        1) # assert disabled
            [[ $2 = n ]]
            return
    esac

    # not found
    return 127
}

run_function_safe() {
    local restoretrap

    set -e

    restoretrap=$(trap -p ERR)
    trap '$pkgfunc' ERR

    run_function "$1"

    eval $restoretrap

    set +e
}

run_function() {
    if [[ -z $1 ]]; then return 1; fi
    local pkgfunc="$1"

    if assert_option "buildflags" "n"; then
        unset CFLAGS CXXFLAGS LDFLAGS
    fi

    if assert_option "makeflags" "n"; then
        unset MAKEFLAGS
    fi

    cd $src

    export CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS CHOST
    # save our shell options so pkgfunc() can't override what we need
    local shellopts=$(shopt -p)

    "$pkgfunc"

    # reset our shell options
    eval "$shellopts"
}

run_package() {
    local pkgfunc
    if [[ -z $1 ]]; then
        pkgfunc="package"
    else
        pkgfunc="package_$1"
    fi

    run_function_safe "$pkgfunc"
}

check_integrity() {
    if [[ -z $s ]]; then return 1; fi

    local match=1 bits=(1 224 256 384 512)

    for bit in ${bits[@]}; do
        shasum=$(sha${bit}sum $tmp/$file | cut -d' ' -f1)
        if [[ " ${s[*]} " =~ " $shasum " ]]; then
            match=0
        fi
    done

    echo "checking: $file"
    if [[ $match == 1 ]]; then
        echo ">>> integrity mismatch"
        exit 1
    fi
}

download() {
    if [[ $1 == git* ]]; then
        if [[ $1 == git+* ]]; then
            _g=${1#git+}; _giturl=${_g%%#*}
        else
            _giturl=${1%%#*}
        fi
        _gitref=${1#*#}
        gitcmd="git checkout --force --no-track -B PAN"
        git clone $_giturl $src
        pushd $src &>/dev/null
        if [[ $_gitref != $_giturl ]]; then
            case ${_gitref%%=*} in
                commit|tag) $gitcmd ${_gitref##*=};;
                branch) $gitcmd origin/${_gitref##*=};;
                *) echo "${_gitref}: not supported"; exit 1;;
            esac
        fi
        popd &>/dev/null
    else
        if [[ $1 =~ "::" ]]; then
            file=${1%::*}; url=${1#*::}
        else
            file=$(basename $1); url=$1
        fi
        if [ ! -f $tmp/$file ]; then
            echo "downloading: $file"
            curl -L -o $tmp/$file $url
        fi

        check_integrity
    fi
}

extract() {
    if assert_option "extract" "n"; then continue; fi

    if assert_option "extract" "y"; then
        if [[ $1 != git* ]]; then
            echo "extracting: $file"
            local cmd="--strip-components=1"
            case $file in
                *.tar.bz2)
                    tar -C $src -jxpf $tmp/$file $cmd;;
                *.tar.xz|*.tar.gz|*.tgz|*.tar)
                    tar -C $src -xpf $tmp/$file $cmd;;
                *.bz2|*.gz|*.zip)
                    bsdtar -C $src -xpf $tmp/$file $cmd;;
                *) echo "$file: archive not supported";;
            esac
        fi
    fi
}

create_archive() {
    cd $pkg

    mkdir -p $pkg/{$inf,$lst}
    echo "n=$n" >> $pkg/$inf/$n
    echo "v=$v" >> $pkg/$inf/$n
    echo "r=$r" >> $pkg/$inf/$n
    echo "g=$g" >> $pkg/$inf/$n
    echo $(printf "%s " "d=(${d[@]})") >> $pkg/$inf/$n
    echo $(printf "%s " "u=(${u[@]})") >> $pkg/$inf/$n

    if assert_option "strip" "y"; then
        find . -type f 2>/dev/null | while read binary; do
            case "$(file -bi "$binary")" in
                *application/x-sharedlib*)
                    strip --strip-unneeded $binary;;
                *application/x-archive*)
                    strip --strip-debug $binary;;
                *application/x-executable*)
                    strip --strip-all $binary;;
            esac
        done
    fi

    touch $pkg/$lst/$n

    if assert_option "emptydirs" "n"; then
        find . -type d -empty -delete
    fi

    find ./ | sed 's/.\//\//' | sort > $pkg/$lst/$n

    tar -cpJf $bld/arc/$n-$v-$r.$pkgext ./
}

for i in $@; do
    case "$i" in
        fake_root) INFAKEROOT=1;;
    esac
done

unset n v r g d m b o u s src pkg rcs

source_safe /etc/pan.conf

get_recipes

pn=$1; source_safe $rcs/$pn/recipe

if  [[ -L "$rcs/$pn" && -d "$rcs/$pn" ]]; then
    echo "$pn is a split package of $n. Try building $n."; exit 0
fi

mkdir -p $bld/arc $src/$n-$v $tmp

_pkg=$pkg; _src=$src; src=$src/$n-$v; rcs=$rcs/$n

if (( INFAKEROOT )); then
    if [ ${#n[@]} -ge 2 ]; then
        for pn in ${n[@]}; do
            n=$pn
            pkg=$pkg/$n
            mkdir -p $pkg
            run_package $pn
            if [ -f "$rcs/system.$n" ]; then
                mkdir -p $pkg/$sys
                cp $rcs/system.$n $pkg/$sys/$n
            fi
            create_archive
            pkg=$_pkg
        done
    else
        pkg=$pkg/$n
        mkdir -p $pkg
        run_package
        if [ -f "$rcs/system" ]; then
            mkdir -p $pkg/$sys; cp $rcs/system $pkg/$sys/$n
        fi
        create_archive
    fi
    rm -rf $_pkg $_src
else
    if [ -n "$u" ]; then
        for src_url in "${u[@]}"; do
            download $src_url
            extract $src_url
        done
    fi

    echo "building: $n ($v)"
    if [ -d "$src/$n-$v" ]; then cd $src/$n-$v; else cd $src; fi

    if type build >/dev/null 2>&1; then
        run_function_safe "build"
    fi
    fakeroot -- $0 $1 fake_root || exit $?
fi