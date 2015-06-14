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
NoExtract=false

GetRcs() {
    if [ ! -d $rcs ]; then
    	git clone $gitrcs $rcs
		chgrp -R users $rcs
		chmod -R g+w $rcs
	fi
}

PkgLst() {
    for _pkg in $(ls $rcs); do
        if [ -f $rcs/$_pkg/recipe ]; then
            . $rcs/$_pkg/recipe
        fi
        if [ -z "$s" ]; then continue; fi
        if [ "$s" = "$gn" ]; then plst+=($n); fi
        unset s
    done

    plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
}

GetPkg() {
    echo "downloading: $1"
    curl -f -L -o $arc/$1 $getpkg/$1
}

RtDeps() {
    if [ -f $rcs/$1/recipe ]; then
        . $rcs/$1/recipe
    fi

    deps=(${deps[@]} $1)
    for dep in ${d[@]}; do
        if [[ ${deps[*]} =~ $dep ]]; then
            continue
        else
            deps=(${deps[@]} $dep)
            RtDeps $dep
        fi
    done
}

Add() {
    GetRcs

    if [ -f $rcs/$pn/recipe ]; then
        . $rcs/$pn/recipe
    else
        echo "$pn: recipe file not found"; exit 1
    fi

    RtDeps $pn
    deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))

    for dep in ${deps[@]}; do
        if [ ! -f $rcs/$dep/recipe ]; then
            mdeps+=($dep); echo "$dep: recipe file not found"
        else
            . $rcs/$dep/recipe; export n v
            if [ -f "$root/$inf/$n" ]; then
                if [ "$n" = "$pn" ]; then
                    _deps+=($n)
                else
                    continue
                fi
            else
               _deps+=($n)
            fi
        fi
    done

    if [ "${#mdeps[@]}" -ge "1" ]; then
        echo "missing deps: ${mdeps[@]}"; exit 1
    fi

    for dep in ${_deps[@]}; do
        . $rcs/$dep/recipe;
        if [ ! -f $arc/$n-$v.$pkgext ]; then
            GetPkg $n-$v.$pkgext
            if [ ! -f $arc/$n-$v.$pkgext ]; then
                echo "$n-$v.$pkgext: file not found"
                _pkg+=($n)
            fi
        fi
    done

    if [ "${#_pkg[@]}" -ge "1" ]; then
        echo "missing archive(s): ${_pkg[@]}"; exit 1
    fi

    for dep in ${_deps[@]}; do
        . $rcs/$dep/recipe; export n v
        echo "installing: $n ($v)"
        tar -C $root -xpf $arc/$n-$v.$pkgext
        chmod 777 $root/pkg &>/dev/null

        if [ -f "$root/$sys/$n" ]; then . $root/$sys/$n
            if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
                ". $sys/$n; if type _add >/dev/null 2>&1; then _add; fi"
            else
                if type _add >/dev/null 2>&1; then _add; fi
            fi
        fi

        if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [ADD] $n ($v)" >> $root/$log/add
    done
    deps=(); mdeps=(); _deps=(); _pkg=()
}

GrpAdd() {
    GetRcs; PkgLst

    for _pkg in ${plst[@]}; do
        . $rcs/$_pkg/recipe
        if [ ! -f $arc/$n-$v.$pkgext ]; then
            GetPkg $n-$v.$pkgext
            if [ ! -f $arc/$n-$v.$pkgext ]; then
                echo "$n: archive file not found"
                _pkg_+=($n)
            fi
        fi
    done

    if [ "${#_pkg_[@]}" -ge "1" ]; then
        echo "missing archive(s): ${_pkg_[@]}"; exit 1
    fi

    for _pkg in ${plst[@]}; do
        . $rcs/$_pkg/recipe
        echo "installing: $n ($v)"
        tar -C $root -xpf $arc/$n-$v.$pkgext
        chmod 777 $root/pkg &>/dev/null

        if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [ADD] $n ($v)" >> $root/$log/add
    done

    for _pkg in ${plst[@]}; do
        . $rcs/$_pkg/recipe; export n v
        if [ -f "$root/$sys/$n" ]; then . $root/$sys/$n
            if [ "$root" != "/" ]; then chroot $root /bin/sh -c \
                ". $sys/$n; if type _add >/dev/null 2>&1; then _add; fi"
            else
                if type _add >/dev/null 2>&1; then _add; fi
            fi
        fi
    done
    plst=()
}

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

include() {
    cp $rcs/$pn/recipe /tmp/$pn.recipe
    sed -i -e "s#build() {#build() {\n    set -e#" /tmp/$pn.recipe
    . /tmp/$pn.recipe
}

Bld() {
    set -e

    GetRcs

    if [ -f $rcs/$pn/recipe ]; then
        include
    else
        echo "$pn: recipe file not found"; exit 1
    fi

    if [ -z "$p" ]; then p=$n-$v; fi

    for opt in "${o[@]}"; do
        if [ "$opt" = "noextract" ]; then NoExtract=true; fi
    done

    _rcs=$rcs; rcs=$rcs/$n; _pkg=$pkg; pkg=$pkg/$n
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

    echo "building: $n ($v)"
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
    rm -rf $_pkg $src /tmp/$n.recipe

    rcs=$_rcs; pkg=$_pkg; p=
}

GrpBld() {
	set -e

    GetRcs; PkgLst

    for _pkg in ${plst[@]}; do
        . $rcs/$_pkg/recipe
        if [ ! -f /tmp/$_pkg.$gn ]; then
            bld $_pkg
            if [ $? -eq 0 ]; then
                touch /tmp/$_pkg.$gn
            fi
        fi
    done
    plst=()
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
}

GrpDel() {
    for _pkg in $(ls $root/$inf); do
        if [ -f $root/$inf/$_pkg ]; then
            . $root/$inf/$_pkg
        fi
 
        if [ "$s" = "$gn" ]; then plst+=($n); fi
    done

    plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))

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

    for _pkg in ${plst[@]}; do
        grpsys=true; pn=$_pkg; Del
    done

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
    plst=()
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
            echo "address: $u"
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
    GetRcs

    if [ -f $rcs/$pn/recipe ]; then
        . $rcs/$pn/recipe; v1=$v; v=
    else
        echo "$pn: recipe file not found"
    fi

    if [ -f $inf/$n ]; then
        . $inf/$n; v2=$v; v=
    else
        echo "$n: info file not found"; continue
    fi

    v=$(echo -e "$v1\n$v2" | sort -V | tail -n1)

    if [ "$v1" != "$v2" ]; then
        if [ "$v1" = "$v" ]; then
            echo "updating: $n ($v2 -> $v1)"

            if [ -f "$sys/$n" ]; then . $sys/$n
                if type upd_ >/dev/null 2>&1; then upd_; fi
            fi

            rn=$lst/$n; cp $rn $rn.bak

            if [ -f $arc/$n-$v.$pkgext ]; then
                tar -C $root -xpf $arc/$n-$v.$pkgext
            fi

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
        fi
    fi
}

GrpUpd() {
    rm -rf $rcs; GetRcs

    for _pkg in $(ls $rcs); do
        if [ -f $rcs/$_pkg/recipe ]; then
           . $rcs/$_pkg/recipe
        fi
        plst+=($n)
    done

    plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))

    for _pkg in ${plst[@]}; do
        upd $_pkg
    done
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
            echo "  -U, --grp-update <name>         update group of packages"
            exit 1;;
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
        -U|--grp-update) _GrpUpd=true;;
    esac
done

if [ "$_Add" = true ]; then shift
    for i in $@; do
        if [ "${i%=*}" = "root" ]; then continue; fi
        pn=$i; Add
    done
fi

if [ "$_GrpAdd" = true ]; then shift
    for i in $@; do
        if [ "${i%=*}" = "root" ]; then continue; fi
        gn=$i; GrpAdd
    done
fi

if [ "$_Bld" = true ]; then shift
    for i in $@; do
        pn=$i; Bld
    done
fi

if [ "$_GrpBld" = true ]; then shift
    for i in $@; do
        gn=$i; GrpBld
    done
fi

if [ "$_Con" = true ]; then shift; Con; fi

if [ "$_Del" = true ]; then shift
    for i in $@; do
        if [ "${i%=*}" = "root" ]; then continue; fi
        pn=$i; Del
    done
fi

if [ "$_GrpDel" = true ]; then shift
    for i in $@; do
        if [ "${i%=*}" = "root" ]; then continue; fi
        gn=$i; GrpDel
    done
fi

if [ "$_Grp" = true ]; then shift; gn=$1; Grp; fi
if [ "$_GrpLst" = true ]; then shift; GrpLst; fi
if [ "$_Inf" = true ]; then shift; pn=$1; Inf; fi
if [ "$_Lst" = true ]; then shift; pn=$1; Lst; fi
if [ "$_Own" = true ]; then shift; pt=$1; Own; fi

if [ "$_Upd" = true ]; then shift
    for i in $@; do
        pn=$i; Upd
    done
fi

if [ "$_GrpUpd" = true ]; then shift; GrpUpd; fi