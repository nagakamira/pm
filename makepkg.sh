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

print_bold() {
    printf "\e[1m$1\e[0m $2\n"
}

print_green() {
    local x=">>>"
    if [[ -n $2 ]]; then x=$2; fi
    printf "\e[1m\e[32m$x\e[0m $1\n"
}

print_red() {
    printf "\e[1m\e[31m>>>\e[0m $1\n"
}

source_safe() {
    if ! source "$1" >/dev/null 2>&1; then
        print_red "$1: file not found"; exit 1
    fi
}

get_recipes() {
    if [ ! -d $rcsdir ] && [ -n $rcsrepo ]; then
        git clone $rcsrepo $rcsdir
    elif [ -z $rcsrepo ]; then
        print_red "please set recipe repository in /etc/pan.conf"; exit 1
    fi
}

check_option() {
    local needle=$1; shift
    local options=$@

    for o in ${options[@]}; do
        if [[ $o = "$needle" ]]; then
            # enabled
            return 0
        elif [[ $o = "!$needle" ]]; then
            # disabled
            return 1
        fi
    done

    # not found
    return 127
}

assert_option() {
    check_option "$1" ${opt[@]}
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
        unset CPPFLAGS CFLAGS CXXFLAGS LDFLAGS
    fi

    if assert_option "makeflags" "n"; then
        unset MAKEFLAGS
    fi

    print_green "entering $src_pkg_ver"; cd $src_pkg_ver

    export CPPFLAGS CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS CHOST
    # save our shell options so pkgfunc() can't override what we need
    local shellopts=$(shopt -p)

    "$pkgfunc"

    # reset our shell options
    eval "$shellopts"

    cd $topdir
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

support_alias() {
    if [[ -n $sha1sum ]]; then sha=(${sha1sum[@]}); fi
    if [[ -n $sha224sum ]]; then sha=(${sha224sum[@]}); fi
    if [[ -n $sha256sum ]]; then sha=(${sha256sum[@]}); fi
    if [[ -n $sha384sum ]]; then sha=(${sha384sum[@]}); fi
    if [[ -n $sha512sum ]]; then sha=(${sha512sum[@]}); fi

    if [[ -n $url ]]; then src=(${url[@]}); fi
}

check_integrity() {
    if [[ -z $sha ]]; then return 1; fi

    local match=0 bits=(1 224 256 384 512)

    for bit in ${bits[@]}; do
        shasum=$(sha${bit}sum $tmpdir/$file | cut -d' ' -f1)
        if [[ " ${sha[*]} " =~ " $shasum " ]]; then
            match=1
        fi
    done

    print_bold "checking:" $file
    if [[ $match == 0 ]]; then
        print_red "integrity mismatch"
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
        git clone $giturl $src_pkg_ver
        pushd $src_pkg_ver &>/dev/null
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
            file=${su%::*}; src_url=${su#*::}
        else
            file=$(basename $su); src_url=$su
        fi
        if [ ! -f $tmpdir/$file ]; then
            print_bold "downloading:" $file
            curl -L -o $tmpdir/$file $src_url
        fi
    fi
}

extract() {
    local cdm su=$1

    check_integrity

    e_msg="extracting:"; c_msg="copying:"

    if assert_option "extract" "n"; then
        print_bold $c_msg $file
        print_green $src_pkg_ver/$file "-->"
        cp -a $tmpdir/$file $src_pkg_ver; continue
    fi

    if assert_option "extract" "y"; then
        if [[ $su != git* ]]; then
            if [ ${#src[@]} -eq 1 ]; then cmd="--strip-components=1"; fi
            if assert_option "stripcomponents" "n"; then unset cmd; fi
            case $file in
                *.tar.bz2)
                    print_bold $e_msg $file; print_green $src_pkg_ver
                    tar -C $src_pkg_ver -jxpf $tmpdir/$file $cmd;;
                *.tar.xz|*.tar.gz|*.tgz|*.tar)
                    print_bold $e_msg $file; print_green $src_pkg_ver
                    tar -C $src_pkg_ver -xpf $tmpdir/$file $cmd;;
                *.bz2|*.zip)
                    print_bold $e_msg $file; print_green $src_pkg_ver
                    bsdtar -C $src_pkg_ver -xpf $tmpdir/$file $cmd;;
                *.gz)
                    print_bold $e_msg $file; print_green $src_pkg_ver
                    gunzip -c $tmpdir/$file > $src_pkg_ver/${file%.*};;
                *)
                    print_bold $c_msg $file
                    print_green $src_pkg_ver/$file "-->"
                    cp -a $tmpdir/$file $src_pkg_ver;;
            esac
        fi
    fi
}

create_archive() {
    cd $pkgdir

    mkdir -p $pkgdir/{$infdir,$lstdir}
    echo "pkg=$pkg" >> $pkgdir/$infdir/$pkg
    echo "ver=$ver" >> $pkgdir/$infdir/$pkg
    echo "rel=$rel" >> $pkgdir/$infdir/$pkg

    if [[ -n $grp ]]; then
        echo "grp=$grp" >> $pkgdir/$infdir/$pkg
    fi
    if [[ -n $dep ]]; then
        echo $(printf "%s " "dep=(${dep[@]})") >> $pkgdir/$infdir/$pkg
    fi
    if [[ -n $src ]]; then
        echo $(printf "%s " "src=(${src[@]})") >> $pkgdir/$infdir/$pkg
    fi

    if assert_option "strip" "y"; then
        print_green "stripping unneeded symbols"
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

    touch $pkgdir/$lstdir/$pkg

    if assert_option "emptydirs" "n"; then
        find . -type d -empty -delete
    fi

    find ./ | sed 's/.\//\//' | sort > $pkgdir/$lstdir/$pkg

    print_green "compressing $pkg-$ver-$rel.$ext"
    tar -cpJf $arcdir/$pkg-$ver-$rel.$ext ./
}

for i in $@; do
    case "$i" in
        fake_root) INFAKEROOT=1;;
    esac
done

if [ $# -eq 0 ]; then echo "try $0 <recipe>"; exit 1; fi

unset pkg ver rel grp dep mkd bak opt src sha srcdir pkgdir rcsdir

source_safe /etc/pan.conf; topdir=`pwd`
arcdir=$user_arcdir; rcsdir=$user_rcsdir

if [[ -f "$1" && "$(basename $1)" == "recipe" ]]; then
    pushd $(dirname $1) >/dev/null 2>&1
    rcsdir=`pwd`; source_safe $rcsdir/recipe
    popd >/dev/null 2>&1
else
    get_recipes; rc_pn=$1; source_safe $rcsdir/$rc_pn/recipe

    if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then
        echo "$rc_pn is a split package of $pkg. Try building $pkg."; exit 0
    fi

    rcsdir=$rcsdir/$pkg
fi

_pkgdir=$pkgdir; src_pkg_ver=$srcdir/$pkg-$ver

support_alias

if [ ${#src[@]} -ge 2 ]; then src_pkg_ver=$srcdir; fi

if assert_option "srcpkgverdir" "n"; then src_pkg_ver=$srcdir; fi

mkdir -p $arcdir $src_pkg_ver $tmpdir

if (( INFAKEROOT )); then
    if [ ${#pkg[@]} -ge 2 ]; then
        for pn in ${pkg[@]}; do
            pkg=$pn
            pkgdir=$pkgdir/$pkg
            mkdir -p $pkgdir
            print_bold "packaging:" "$pkg ($ver-$rel)"
            run_package $pn
            if [ -f "$rcsdir/system.$pkg" ]; then
                mkdir -p $pkgdir/$sysdir
                cp $rcsdir/system.$pkg $pkgdir/$sysdir/$pkg
            fi
            create_archive
            pkgdir=$_pkgdir; unset grp dep bak opt
        done
    else
        pkgdir=$pkgdir/$pkg
        mkdir -p $pkgdir
        print_bold "packaging:" "$pkg ($ver-$rel)"
        run_package
        if [ -f "$rcsdir/system" ]; then
            mkdir -p $pkgdir/$sysdir
            cp $rcsdir/system $pkgdir/$sysdir/$pkg
        fi
        create_archive
    fi
    rm -rf $_pkgdir $srcdir
else
    if [ -n "$src" ]; then
        for src_url in "${src[@]}"; do
            download $src_url
            extract $src_url
        done
    fi

    print_bold "building:" "$pkg ($ver-$rel)"
    if type build >/dev/null 2>&1; then
        run_function_safe "build"
    fi
    fakeroot -- $0 $1 fake_root || exit $?
fi