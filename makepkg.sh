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
    if [ ! -d $rcsdir ]; then
        git clone $rcsrepo $rcsdir
        chgrp -R users $rcsdir
        chmod -R g+w $rcsdir
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

    cd $src_nv

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
        shasum=$(sha${bit}sum $tmpdir/$file | cut -d' ' -f1)
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
    local su=$1
    if [[ $su == git* ]]; then
        if [[ $su == git+* ]]; then
            gitplus=${su#git+}; giturl=${gitplus%%#*}
        else
            giturl=${su%%#*}
        fi
        _gitref=${su#*#}
        gitcmd="git checkout --force --no-track -B PAN"
        git clone $giturl $src_nv
        pushd $src_nv &>/dev/null
        if [[ $_gitref != $giturl ]]; then
            case ${_gitref%%=*} in
                commit|tag) $gitcmd ${_gitref##*=};;
                branch) $gitcmd origin/${_gitref##*=};;
                *) echo "${_gitref}: not supported"; exit 1;;
            esac
        fi
        popd &>/dev/null
    else
        if [[ $su =~ "::" ]]; then
            file=${su%::*}; url=${su#*::}
        else
            file=$(basename $su); url=$su
        fi
        if [ ! -f $tmpdir/$file ]; then
            echo "downloading: $file"
            curl -L -o $tmpdir/$file $url
        fi

        check_integrity
    fi
}

extract() {
    local su=$1
    if assert_option "extract" "n"; then
        cp -a $tmpdir/$file $srcdir; continue
    fi

    if assert_option "extract" "y"; then
        if [[ $su != git* ]]; then
            echo "extracting: $file"
            local cmd="--strip-components=1"
            case $file in
                *.tar.bz2)
                    tar -C $src_nv -jxpf $tmpdir/$file $cmd;;
                *.tar.xz|*.tar.gz|*.tgz|*.tar)
                    tar -C $src_nv -xpf $tmpdir/$file $cmd;;
                *.bz2|*.gz|*.zip)
                    bsdtar -C $src_nv -xpf $tmpdir/$file $cmd;;
                *) cp -a $tmpdir/$file $srcdir;;
            esac
        fi
    fi
}

create_archive() {
    cd $pkgdir

    mkdir -p $pkgdir/{$infdir,$lstdir}
    echo "n=$n" >> $pkgdir/$infdir/$n
    echo "v=$v" >> $pkgdir/$infdir/$n
    echo "r=$r" >> $pkgdir/$infdir/$n

    if [[ -n $g ]]; then
        echo "g=$g" >> $pkgdir/$infdir/$n
    fi
    if [[ -n $d ]]; then
        echo $(printf "%s " "d=(${d[@]})") >> $pkgdir/$infdir/$n
    fi
    if [[ -n $u ]]; then
        echo $(printf "%s " "u=(${u[@]})") >> $pkgdir/$infdir/$n
    fi

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

    touch $pkgdir/$lstdir/$n

    if assert_option "emptydirs" "n"; then
        find . -type d -empty -delete
    fi

    find ./ | sed 's/.\//\//' | sort > $pkgdir/$lstdir/$n

    tar -cpJf $blddir/arc/$n-$v-$r.$pkgext ./
}

for i in $@; do
    case "$i" in
        fake_root) INFAKEROOT=1;;
    esac
done

unset n ver rel grp dep mkd bak opt url sha srcdir pkgdir rcsdir

source_safe /etc/pan.conf

get_recipes

pn=$1; source_safe $rcsdir/$pn/recipe

if  [[ -L "$rcsdir/$pn" && -d "$rcsdir/$pn" ]]; then
    echo "$pn is a split package of $n. Try building $n."; exit 0
fi

_pkgdir=$pkgdir; src_nv=$srcdir/$n-$v; rcsdir=$rcsdir/$n

mkdir -p $blddir/arc $src_nv $tmpdir

if (( INFAKEROOT )); then
    if [ ${#n[@]} -ge 2 ]; then
        for pn in ${n[@]}; do
            n=$pn
            pkgdir=$pkgdir/$n
            mkdir -p $pkgdir
            run_package $pn
            if [ -f "$rcsdir/system.$n" ]; then
                mkdir -p $pkgdir/$sysdir
                cp $rcsdir/system.$n $pkgdir/$sysdir/$n
            fi
            create_archive
            pkgdir=$_pkgdir
        done
    else
        pkgdir=$pkgdir/$n
        mkdir -p $pkgdir
        run_package
        if [ -f "$rcsdir/system" ]; then
            mkdir -p $pkgdir/$sysdir; cp $rcsdir/system $pkgdir/$sysdir/$n
        fi
        create_archive
    fi
    rm -rf $_pkgdir $srcdir
else
    if [ -n "$u" ]; then
        for src_url in "${u[@]}"; do
            download $src_url
            extract $src_url
        done
    fi

    echo "building: $n ($v)"
    if [ -d "$src_nv" ]; then cd $src_nv; else cd $srcdir; fi

    if type build >/dev/null 2>&1; then
        run_function_safe "build"
    fi
    fakeroot -- $0 $1 fake_root || exit $?
fi