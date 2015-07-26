#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Pan is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

_Add=false
_GrpAdd=false
_Bld=false
_GrpBld=false
_Con=false
_Del=false
_GrpDel=false
_Grp=false
_GrpLst=false
_Inf=false
_Lst=false
_Own=false
_Upd=false
_GrpUpd=false
grpsys=false
updrcs=true
reinst=false
NoExtract=false
NoStrip=false

SetPrm() {
    chgrp -R users $rcs
    chmod -R g+w $rcs
}
GetRcs() {
    if [ ! -d $rcs ]; then
    	git clone $gitrcs $rcs; SetPrm
	fi
}

PkgLst() {
    for _pkg in $(ls $rcs); do
        if [ -f $rcs/$_pkg/recipe ]; then
            . $rcs/$_pkg/recipe
        fi
        if [ -z "$s" ]; then continue; fi
        if [ "$s" = "$gn" ]; then plst+=($n); fi
        unset n v s d u p o
    done

    plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
}

GetPkg() {
    for _pkg in ${plst[@]}; do
        . $rcs/$_pkg/recipe
        if [ ! -f $arc/$n-$v.$pkgext ]; then
            echo "downloading: $n-$v.$pkgext"
            curl -f -L -o $arc/$n-$v.$pkgext $getpkg/$n-$v.$pkgext
            if [ ! -f $arc/$n-$v.$pkgext ]; then
                echo "$n: archive file not found"
                _pkg_+=($n)
            fi
        fi
    done

    if [ "${#_pkg_[@]}" -ge "1" ]; then
        echo "missing archive(s): ${_pkg_[@]}"; exit 1
    fi
}

RtDeps() {
    if [ -f $rcs/$1/recipe ]; then
        . $rcs/$1/recipe
    fi

    deps=(${deps[@]} $1)
    for dep in ${d[@]}; do
        if [[ ${deps[*]} =~ " $dep " ]]; then
            continue
        else
            deps=(${deps[@]} $dep)
            RtDeps $dep
        fi
    done
}

Add() {
    GetRcs

    for pn in $args; do
        if [ "${pn%=*}" = "root" ]; then continue; fi
        if [ "${pn}" = "reinstall" ]; then continue; fi

        if [ -f $rcs/$pn/recipe ]; then
            . $rcs/$pn/recipe
        else
            echo "$pn: recipe file not found"; exit 1
        fi
        alst+=($pn)
        RtDeps $pn
    done

    deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))

    for dep in ${deps[@]}; do
        if [ ! -f $rcs/$dep/recipe ]; then
            mdeps+=($dep); echo "$dep: recipe file not found"
        else
            . $rcs/$dep/recipe
            if [ -f "$root/$inf/$n" ]; then
                for pn in ${alst[@]}; do
                    if [ "$n" = "$pn" ] && [ "$reinst" = true ]; then
                        _deps+=($n)
                    else
                        continue
                    fi
                done
                continue
            else
               _deps+=($n)
            fi
        fi
    done

    if [ "${#mdeps[@]}" -ge "1" ]; then
        echo "missing deps: ${mdeps[@]}"; exit 1
    fi

    plst=(${_deps[@]}); GetPkg

    for dep in ${_deps[@]}; do
        . $rcs/$dep/recipe
        echo "installing: $n ($v)"
        tar -C $root -xpf $arc/$n-$v.$pkgext
        chmod 777 $root/pkg &>/dev/null

        if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [ADD] $n ($v)" >> $root/$log/add
    done

    for dep in ${_deps[@]}; do
        . $rcs/$dep/recipe; export n v
        if [ -f "$root/$sys/$n" ]; then . $root/$sys/$n
            if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
                ". $sys/$n; if type _add >/dev/null 2>&1; then _add; fi"
            else
                if type _add >/dev/null 2>&1; then _add; fi
            fi
        fi
    done
}

GrpAdd() {
    GetRcs

    for gn in $args; do
        if [ "${gn%=*}" = "root" ]; then continue; fi
        if [ "${gn}" = "reinstall" ]; then continue; fi
        PkgLst
    done

    GetPkg; args=${plst[@]}; Add
}

download() {
    if [ "${1%://*}" = "git" ]; then
        if [ ! -d $src/$n-$v ]; then
            git clone $1 $src/$n-$v
        fi
    else
        if [[ $1 =~ "::" ]]; then
            file=${1%::*}; url=${1#*::}
        else
            file=$(basename $1); url=$1
        fi
        if [ ! -f $arc/$file ]; then
            echo "downloading: $file"
            curl -L -o $arc/$file $url
        fi
    fi
}

extract() {
    if [ ! "${1%://*}" = "git" ]; then
        if [ "$NoExtract" = false ]; then
            echo "extracting: $file"
            case $file in
                *.tar.bz2) tar -C $src -jxpf $arc/$file;;
                *.bz2)     bzip2 -dc $arc/$file > $src/${file%.*};;
                *.tar.xz)  tar -C $src -xpf $arc/$file;;
                *.tar.gz)  tar -C $src -xpf $arc/$file;;
                *.tgz)     tar -C $src -xpf $arc/$file;;
                *.tar)     tar -C $src -xpf $arc/$file;;
                *.gz)      gunzip -c $arc/$file > $src/${file%.*};;
                *.zip)     unzip -d $src $arc/$file;;
                *.7z)      7za x $file -o$src;;
                *)         echo "$file: not supported";;
            esac
        fi
    fi
}

_package() {
    cd $pkg; mkdir -p $pkg/{$inf,$lst}
    echo "n=$n" >> $pkg/$inf/$n
    echo "v=$v" >> $pkg/$inf/$n
    echo "s=$s" >> $pkg/$inf/$n
    printf "%s " "d=(${d[@]})" >> $pkg/$inf/$n
    echo -e "" >> $pkg/$inf/$n
    printf "%s " "u=(${u[@]})" >> $pkg/$inf/$n
    echo -e "" >> $pkg/$inf/$n
    find -L ./ | sed 's/.\//\//' | sort > $pkg/$lst/$n

    if [ "$NoStrip" = false ]; then
        find . -type f 2>/dev/null | while read binary; do
            case "$(file -bi "$binary")" in
                *application/x-sharedlib*)
                    fakeroot -i $src/state.$n -s $src/state.$n -- strip --strip-unneeded $binary;;
                *application/x-archive*)
                    fakeroot -i $src/state.$n -s $src/state.$n -- strip --strip-debug $binary;;
                *application/x-executable*)
                    fakeroot -i $src/state.$n -s $src/state.$n -- strip --strip-all $binary;;
            esac
        done
    fi

    fakeroot -i $src/state.$n -- tar -cpJf $arc/$n-$v.$pkgext ./
}

Bld() {
    set -e

    GetRcs

    for pn in $args; do
        _rcs=$rcs; _pkg=$pkg
        mkdir -p $arc $src

        if [ -f $rcs/$pn/recipe ]; then
            . $rcs/$pn/recipe
        else
            echo "$pn: recipe file not found"; exit 1
        fi

        if [ -z "$p" ]; then p=$n-$v; fi

        for opt in "${o[@]}"; do
            if [ "$opt" = "noextract" ]; then NoExtract=true; fi
            if [ "$opt" = "nostrip" ]; then NoStrip=true; fi
        done

        if [ -n "$u" ]; then
            if [ "${#u[@]}" -gt "1" ]; then
                for _u in "${u[@]}"; do
                    download $_u
                    extract $_u
                done
            else
                download $u
                extract $u
            fi
        else
            p=./
        fi

        echo "building: $n ($v)"
        if [ -d "$src/$p" ]; then cd $src/$p; else cd $src; fi

        cp $rcs/$n/recipe /tmp/$n.recipe
        sed -i -e "s#build() {#build() {\n    set -e#" /tmp/$n.recipe

        if [ ${#n[@]} -ge 2 ]; then
            for i in ${!n[@]}; do
                sed -i -e "s#package_${n[$i]}() {#package_${n[$i]}() {\n    set -e#" /tmp/$n.recipe
            done
        else
            sed -i -e "s#package() {#package() {\n    set -e#" /tmp/$n.recipe
        fi

        . /tmp/$n.recipe; rcs=$rcs/$n; _pwd=`pwd`

        export CHOST CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS arc pkg rcs src n v u p

        if type build >/dev/null 2>&1; then build; fi

        if [ ${#n[@]} -ge 2 ]; then
            for i in ${!n[@]}; do
                n=${n[$i]}; s=${s[$i]}
                pkg=$pkg/$n; mkdir -p $pkg
                s=$(echo $(declare -f package_$n | sed -n 's/s=\(.*\);/\1/p'))
                d=($(declare -f package_$n | sed -n 's/d=\(.*\);/\1/p' | tr -d "()" | tr -d "'"))

                export -f package_$n; fakeroot -s $src/state.$n package_$n

                if [ -f "$rcs/system.$n" ]; then
                    mkdir -p $pkg/$sys; cp $rcs/system.$n $pkg/$sys/$n
                fi

                _package; pkg=$_pkg; cd $_pwd
            done
        else
            pkg=$pkg/$n; mkdir -p $pkg

            export -f package; fakeroot -s $src/state.$n package

            if [ -f "$rcs/system" ]; then
                mkdir -p $pkg/$sys; cp $rcs/system $pkg/$sys/$n
            fi

            _package
        fi

        rm -rf $_pkg $src /tmp/$n.recipe
        rcs=$_rcs; pkg=$_pkg; p=
    done
}

GrpBld() {
    set -e

    GetRcs

    for gn in $args; do PkgLst; done

    for _pkg_ in ${plst[@]}; do
        if [ ! -f /tmp/$_pkg_ ]; then
        	args=($_pkg_); Bld
            if [ $? -eq 0 ]; then
                touch /tmp/$_pkg_
            fi
        fi
    done
}

Con() {
    out=/tmp/out.txt

    cat $lst/* | sort -n | uniq -d > $out
    for i in $(cat $out); do
        if [ ! -d "$i" ]; then
            _con=$(grep "$i" $lst/*)
            for ln in $_con; do
                echo "${ln#$lst/}"
            done
        fi
    done
}

Del() {
    for pn in $args; do
        if [ "${pn%=*}" = "root" ]; then continue; fi

        ign="--ignore-fail-on-non-empty"

        if [ -f $root/$inf/$pn ]; then
            . $root/$inf/$pn; export n v
        else
            echo "$pn: info file not found"; exit 1
        fi

        if [ "$grpsys" = false ]; then
            if [ -f "$root/$sys/$n" ]; then
                . $root/$sys/$n
                if type _del >/dev/null 2>&1; then export -f _del; fi
                if type _add >/dev/null 2>&1; then export -f _add; fi
                if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
                    ". $sys/$n; if type del_ >/dev/null 2>&1; then del_; fi"
                else
                    if type del_ >/dev/null 2>&1; then del_; fi
                fi
            fi
        fi

        if [ -f "$root/$lst/$n" ]; then
            echo "removing: $n ($v)"
            list=$(tac $root/$lst/$n)
        else
            continue
        fi

        for l in $list; do
            if [ -L $root/$l ]; then unlink $root/$l
            elif [ -f $root/$l ]; then rm -f $root/$l
            elif [ "$l" = "/" ]; then continue
            elif [ -d $root/$l ]; then rmdir $ign $root/$l
            fi
        done

        if [ "$grpsys" = false ]; then
            if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
                "if type _del >/dev/null 2>&1; then _del; fi"
            else
                if type _del >/dev/null 2>&1; then _del; fi
            fi
        fi

        if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [DEL] $n ($v)" >> $root/$log/del
    done
}

GrpDel() {
    for gn in $args; do
        if [ "${gn%=*}" = "root" ]; then continue; fi

        for _pkg in $(ls $root/$inf); do
            if [ -f $root/$inf/$_pkg ]; then
                . $root/$inf/$_pkg
            fi
 
            if [ "$s" = "$gn" ]; then plst+=($n); fi
        done

        plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
    done

    for _pkg in ${plst[@]}; do
        if [ -f "$root/$sys/$_pkg" ]; then
            . $root/$sys/$_pkg; . $root/$inf/$_pkg; export n v
            cp $root/$inf/$_pkg $root/$inf/$_pkg.inf
            cp $root/$sys/$_pkg $root/$sys/$_pkg.sys
            if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
                ". $sys/$_pkg; if type del_ >/dev/null 2>&1; then del_; fi"
            else
                if type del_ >/dev/null 2>&1; then del_; fi
            fi
        fi
    done

    grpsys=true; args=${plst[@]}; Del

    for _pkg in ${plst[@]}; do
        if [ -f "$root/$sys/$_pkg.sys" ]; then
            . $root/$sys/$_pkg.sys; . $root/$inf/$_pkg.inf; export n v
            if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
                ". $sys/$_pkg.sys; if type _del >/dev/null 2>&1; then _del; fi"
            else
                if type _del >/dev/null 2>&1; then _del; fi
            fi
            rm -f $root/$sys/$_pkg.sys $root/$inf/$_pkg.inf
        fi
    done
}

Grp() {
    GetRcs; PkgLst

    echo "${plst[@]}"
}

GrpLst() {
    GetRcs

    for _pkg in $(ls $rcs); do
        if [ -f $rcs/$_pkg/recipe ]; then
            . $rcs/$_pkg/recipe
        fi
 
       glst+=($s)
    done

    glst=($(echo ${glst[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
    echo "${glst[@]}"
}

Inf() {
    if [ -f $inf/$pn ]; then
        . $inf/$pn

        echo "program: $n"
        echo "version: $v"
        echo "section: $s"
        echo "depends: ${d[@]}"
        if [ -n "$u" ]; then
            if [ "${#u[@]}" -gt "1" ]; then
                for _u in ${u[@]}; do
                    if [[ $_u =~ "::" ]]; then _u=${_u#*::}; fi
                    echo "archive: $_u"
                done
            else
                if [[ $u =~ "::" ]]; then u=${u#*::}; fi
                echo "archive: $u"
            fi
        fi
    else
        if [ -n "$pn" ]; then
            echo "$pn: info not found"
        fi
    fi
}

Lst() {
    if [ -n "$pn" ]; then
        if [ -f $lst/$pn ]; then
            cat $lst/$pn
        else
            echo "$pn: filelist not found"
        fi
    fi
}

Own() {
    if [ -n "$pt" ]; then
        _own=$(grep $pt $lst/*)
        for ln in $_own; do
            echo "${ln#$lst/}"
        done
    fi
}

Upd() {
    if [ "$updrcs" = true ]; then
        if [ -d $rcs ]; then
            cd $rcs; git pull origin master; SetPrm
        else
            GetRcs
        fi
    fi

    for pn in $args; do

        if [ -f $rcs/$pn/recipe ]; then
            . $rcs/$pn/recipe; v1=$v; v=
        else
            echo "$pn: recipe file not found"
        fi

        if [ -f $inf/$n ]; then
            . $inf/$n; v2=$v; v=
        else
            continue
        fi

        v=$(echo -e "$v1\n$v2" | sort -V | tail -n1)

        if [ "$v1" != "$v2" ]; then
            if [ "$v1" = "$v" ]; then
                ulst+=($n)
            fi
        fi
    done

    plst=(${ulst[@]}); GetPkg

    for _pkg in ${ulst[@]}; do
        . $inf/$_pkg; _v=$v
        . $rcs/$_pkg/recipe

        echo "updating: $n ($_v -> $v)"

        if [ -f "$sys/$n" ]; then . $sys/$n
            if type upd_ >/dev/null 2>&1; then upd_; fi
        fi

        rn=$lst/$n; cp $rn $rn.bak

        tar -C $root -xpf $arc/$n-$v.$pkgext
        chmod 777 $root/pkg &>/dev/null

        list=$(comm -23 <(sort $rn.bak) <(sort $rn))

        for l in $list; do
            if [ -L $l ]; then unlink $l
            elif [ -f $l ]; then rm -f $l
            elif [ "$l" = "/" ]; then continue
            elif [ -d $l ]; then rm -r $l
            fi
        done | tac

        rm $rn.bak

        if [ -f "$sys/$n" ]; then . $sys/$n
            if type _upd >/dev/null 2>&1; then _upd; fi
        fi

        if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [UPD] $n ($v)" >> $log/upd
    done
}

GrpUpd() {
    if [ -d $rcs ]; then
        cd $rcs; git pull origin master; SetPrm
    else
        GetRcs
    fi

    for _pkg in $(ls $rcs); do
        if [ -f $rcs/$_pkg/recipe ]; then
           . $rcs/$_pkg/recipe
        fi
        plst+=($n)
    done

    plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))

    updrcs=false; args=${plst[@]}; Upd
}

if [ $# -eq 0 ]; then $0 -h; fi

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` [operation] <parameter>"
            echo "operation:"
            echo "  -a, --add <name>                add a package"
            echo "  -A, --grp-add <name>            add group of packages"
            echo "  -b, --build <name>              build a package"
            echo "  -B, --grp-build <name>          build group of packages"
            echo "  -c, --conflict                  show conflicting files"
            echo "  -d, --delete <name>             delete a package"
            echo "  -D, --grp-delete <name>         delete group of packages"
            echo "  -g, --group <name>              show group of packages"
            echo "  -G, --grp-list                  show all the groups"
            echo "  -i, --info <name>               show package information"
            echo "  -l, --list <name>               show package filelist"
            echo "  -o, --owner <path>              show the file ownership"
            echo "  -u, --update <name>             update a package"
            echo "  -U, --update-all                update all the packages"
            echo "options:"
            echo "  reinstall                       force add a package"
            echo "  root=<directory>                change root directory"
            exit 1;;
        reinstall) reinst=true;;
        root=*)
            root=${i#*=};;
        -a|--add) _Add=true;;
        -A|--grp-add) _GrpAdd=true;;
        -b|--build) _Bld=true;;
        -B|--grp-build) _GrpBld=true;;
        -c|--conflict) _Con=true;;
        -d|--delete) _Del=true;;
        -D|--grp-delete) _GrpDel=true;;
        -g|--group) _Grp=true;;
        -G|--grp-list) _GrpLst=true;;
        -i|--info) _Inf=true;;
        -l|--list) _Lst=true;;
        -o|--owner) _Own=true;;
        -u|--update) _Upd=true;;
        -U|--update-all) _GrpUpd=true;;
    esac
done

if [ "$_Add" = true ]; then shift; args=$@; Add; fi
if [ "$_GrpAdd" = true ]; then shift; args=$@; GrpAdd; fi
if [ "$_Bld" = true ]; then shift; args=$@; Bld; fi
if [ "$_GrpBld" = true ]; then shift; args=$@; GrpBld; fi
if [ "$_Con" = true ]; then shift; Con; fi
if [ "$_Del" = true ]; then shift; args=$@; Del; fi
if [ "$_GrpDel" = true ]; then shift; args=$@; GrpDel; fi
if [ "$_Grp" = true ]; then shift; gn=$1; Grp; fi
if [ "$_GrpLst" = true ]; then shift; GrpLst; fi
if [ "$_Inf" = true ]; then shift; pn=$1; Inf; fi
if [ "$_Lst" = true ]; then shift; pn=$1; Lst; fi
if [ "$_Own" = true ]; then shift; pt=$1; Own; fi
if [ "$_Upd" = true ]; then shift; args=$@; Upd; fi
if [ "$_GrpUpd" = true ]; then shift; GrpUpd; fi