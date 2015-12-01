#!/bin/bash

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Pan is licenced under the GPLv3: http://gplv3.fsf.org

. /etc/pan.conf

_Add=false
_GrpAdd=false
_Bld=false
_GrpBld=false
_BldDep=false
_Con=false
_Del=false
_GrpDel=false
_Grp=false
_GrpLst=false
_Inf=false
_Lst=false
_Own=false
_Sha=false
_Upd=false
_GrpUpd=false
grpsys=false
updrcs=true
reinst=false
skipdep=false
INFAKECHROOT=0

if [[ ${EUID} -eq 0 ]]; then
    arcdir=$root_arcdir; rcsdir=$root_rcsdir
else
    arcdir=$user_arcdir; rcsdir=$user_rcsdir
    if type fakechroot >/dev/null 2>&1; then INFAKECHROOT=1; fi
fi

print_green() {
    local msg=$(echo $1 | tr -s / /)
    printf "\e[1m\e[32m>>>\e[0m $msg\n"
}

print_red() {
    local msg=$(echo $1 | tr -s / /)
    printf "\e[1m\e[31m>>>\e[0m $msg\n"
}

AsRoot() {
    if [[ ${EUID} -ne 0 ]] && [ "$rootdir" = "/" ]; then
        print_red "This script must be run as root."; exit 1
    fi
}

GetRcs() {
    if [ ! -d $rcsdir ] && [ -n $rcsrepo ]; then
        git clone $rcsrepo $rcsdir
    elif [ -z $rcsrepo ]; then
        print_red "please set recipe repository in /etc/pan.conf"; exit 1
    fi
}

PkgLst() {
    local rc_pn
    for rc_pn in $(ls $rcsdir); do
        if [ -f $rcsdir/$rc_pn/recipe ]; then
            . $rcsdir/$rc_pn/recipe
        fi

        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then
            unset pkg ver rel grp dep mkd bak opt src sha; continue
        fi

        if [ ${#pkg[@]} -ge 2 ]; then
            for i in ${!pkg[@]}; do
                grp=$(echo $(declare -f package_${pkg[$i]} | sed -n 's/grp=\(.*\);/\1/p'))
                if [ -z "$grp" ]; then continue; fi
                if [ "$grp" = "$gn" ]; then plst+=(${pkg[$i]}); fi
            done
        else
            if [ -z "$grp" ]; then
                unset pkg ver rel grp dep mkd bak opt src sha; continue
            fi
            if [ "$grp" = "$gn" ]; then plst+=($pkg); fi
        fi
        unset pkg ver rel grp dep mkd bak opt src sha
    done

    plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
}

GetPkg() {
    local rc_pn

    if [ -z $rcsrepo ]; then
        print_red "please set package repository in /etc/pan.conf"; exit 1
    fi

    for rc_pn in ${plst[@]}; do
        . $rcsdir/$rc_pn/recipe
        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then pkg=$rc_pn; fi
        if [ ! -f $arcdir/$pkg-$ver-$rel.$ext ]; then
            print_green "downloading: $pkg-$ver-$rel.$ext"
            curl -f -L -o $arcdir/$pkg-$ver-$rel.$ext $pkgrepo/$pkg-$ver-$rel.$ext
            if [ ! -f $arcdir/$pkg-$ver-$rel.$ext ]; then
                print_red "$arcdir/$pkg-$ver-$rel.$ext: file not found"
                missing_arcs+=($pkg)
            fi
        fi
    done

    if [ "${#missing_arcs[@]}" -ge "1" ]; then
        print_red "missing archive(s): ${missing_arcs[@]}"; exit 1
    fi

    unset pkg ver rel grp dep mkd bak opt src sha
}

ChkSha() {
    if [ -f $arcdir/shasums.tar.xz ]; then
        rm -rf $arcdir/shasums.tar.xz
        curl -s -f -L -o $arcdir/shasums.tar.xz $pkgrepo/shasums.tar.xz
    else
        curl -s -f -L -o $arcdir/shasums.tar.xz $pkgrepo/shasums.tar.xz
    fi

    if [ -f $arcdir/shasums.tar.xz ]; then
        sha_tempdir=$(mktemp -d)
        tar -C $sha_tempdir -xf $arcdir/shasums.tar.xz
        for rc_pn in ${plst[@]}; do
            . $rcsdir/$rc_pn/recipe
            if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then pkg=$rc_pn; fi
            shasum=$(echo "$(sha256sum $arcdir/$pkg-$ver-$rel.$ext | cut -d' ' -f1) ")
            . $sha_tempdir/$pkg-$ver-$rel; sha=$(echo "$sha" | tr '\n' ' ')
            if [ "$sha" != "$shasum" ]; then
                print_red "$pkg: integrity mismatch"
                shasum_arcs+=($pkg)
            fi
        done
        rm -rf $sha_tempdir
    fi

    if [ "${#shasum_arcs[@]}" -ge "1" ]; then
        print_red "missing archive(s): ${shasum_arcs[@]}"; exit 1
    fi

    unset pkg ver rel grp dep mkd bak opt src sha
}

GetDep() {
    local rc_pn=$1 i
    if [ -f $rcsdir/$rc_pn/recipe ]; then
        . $rcsdir/$rc_pn/recipe
    fi

    if [ ${#pkg[@]} -ge 2 ]; then
        for i in ${!pkg[@]}; do
            if [ "${pkg[$i]}" = "$rc_pn" ]; then
                dep=($(declare -f package_${pkg[$i]} | sed -n 's/dep=\(.*\);/\1/p' | tr -d "()" | tr -d "'" | tr -d "\""))
            fi
        done
        unset pkg
    fi

    deps=(${deps[@]} $rc_pn)
    for i in ${dep[@]}; do
        if [[ " ${deps[*]} " =~ " $i " ]]; then
            continue
        else
            deps=(${deps[@]} $i)
            GetDep $i
        fi
    done
}

GrpDep() {
    local rc_pn
    for rc_pn in ${plst[@]}; do
        GetDep $rc_pn
    done
    unset pkg ver rel grp dep mkd bak opt src sha
 
    deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

backup() {
    if [ -n "$bak" ]; then
        for _f in ${bak[@]}; do
            if [ -f $rootdir/$_f ]; then
                cp $rootdir/$_f $rootdir/${_f}.bak
            fi
        done
    fi
}

restore() {
    if [ -n "$bak" ]; then
        for _f in ${bak[@]}; do
            if [ -f $rootdir/${_f}.bak ]; then
                cp $rootdir/$_f $rootdir/${_f}.new
                mv $rootdir/${_f}.bak $rootdir/$_f
            fi
        done
    fi
}

add_pkg_ext() {
    AsRoot
    tempdir=$(mktemp -d)

    tar -C $tempdir -xpf $rc_pn_ext
    . $tempdir/$infdir/*

    print_green "installing: $pkg ($ver-$rel)"
    backup
    tar -C $rootdir -xpf $(dirname $rc_pn_ext)/$pkg-$ver-$rel.$ext
    restore
    unset bak

    if [ ! -d $rootdir/$logdir ]; then mkdir -p $rootdir/$logdir; fi
    echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [ADD] $pkg ($ver-$rel)" >> $rootdir/$logdir/pan.log

    export pkg ver
    if [ -f "$rootdir/$sysdir/$pkg" ]; then . $rootdir/$sysdir/$pkg
        if (( INFAKECHROOT )); then cmd=fakechroot; fi
        if [ "$rootdir" != "/" ]; then $cmd chroot $rootdir /bin/sh -c \
            ". $sysdir/$pkg; if type post_add >/dev/null 2>&1; then post_add; fi"
        else
            if type post_add >/dev/null 2>&1; then post_add; fi
        fi
    fi

    rm -r $tempdir
}

Add() {
    local rc_pn i deps

    for rc_pn in $args; do
        if [ "${rc_pn%=*}" = "rootdir" ]; then continue; fi
        if [ "${rc_pn}" = "reinstall" ]; then continue; fi
        if [ "${rc_pn}" = "skipdep" ]; then continue; fi

        if [[ -f "$rc_pn" && "$(basename $rc_pn)" == *.$ext ]]; then
            pushd $(dirname $rc_pn) >/dev/null 2>&1
            rc_pn_ext=`pwd`/$(basename $rc_pn)
            popd >/dev/null 2>&1
            add_pkg_ext
        else
            _args+=($rc_pn)
        fi
    done

    args=${_args[@]}
    AsRoot; GetRcs

    for rc_pn in $args; do
        if [ "${rc_pn%=*}" = "rootdir" ]; then continue; fi
        if [ "${rc_pn}" = "reinstall" ]; then continue; fi
        if [ "${rc_pn}" = "skipdep" ]; then continue; fi

        if [ -f $rcsdir/$rc_pn/recipe ]; then
            . $rcsdir/$rc_pn/recipe
        else
            print_red "$rcsdir/$rc_pn/recipe: file not found"; exit 1
        fi
        alst+=($rc_pn)
        if [ "$skipdep" = true ]; then deps+=($rc_pn); else GetDep $rc_pn; fi
    done

    deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))

    for i in ${deps[@]}; do
        if [ ! -f $rcsdir/$i/recipe ]; then
            missing_deps+=($i); print_red "$rcsdir/$i/recipe: file not found"
        else
            if [ -f "$rootdir/$infdir/$i" ]; then
                for pn in ${alst[@]}; do
                    if [ "$i" = "$pn" ] && [ "$reinst" = true ]; then
                        _deps+=($i)
                    else
                        continue
                    fi
                done
                continue
            else
               _deps+=($i)
            fi
        fi
    done

    if [ "${#missing_deps[@]}" -ge "1" ]; then
        print_red "missing deps: ${missing_deps[@]}"; exit 1
    fi

    plst=(${_deps[@]}); GetPkg; ChkSha

    for i in ${_deps[@]}; do
        . $rcsdir/$i/recipe
        if  [[ -L "$rcsdir/$i" && -d "$rcsdir/$i" ]]; then pkg=$i; fi

        print_green "installing: $pkg ($ver-$rel)"
        backup
        tar -C $rootdir -xpf $arcdir/$pkg-$ver-$rel.$ext
        restore
        unset bak

        if [ ! -d $rootdir/$logdir ]; then mkdir -p $rootdir/$logdir; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [ADD] $pkg ($ver-$rel)" >> $rootdir/$logdir/pan.log
    done

    for i in ${_deps[@]}; do
        . $rcsdir/$i/recipe
        if  [[ -L "$rcsdir/$i" && -d "$rcsdir/$i" ]]; then pkg=$i; fi
        export pkg ver
        if [ -f "$rootdir/$sysdir/$pkg" ]; then . $rootdir/$sysdir/$pkg
            if (( INFAKECHROOT )); then cmd=fakechroot; fi
            if [ "$rootdir" != "/" ]; then $cmd chroot $rootdir /bin/sh -c \
                ". $sysdir/$pkg; if type post_add >/dev/null 2>&1; then post_add; fi"
            else
                if type post_add >/dev/null 2>&1; then post_add; fi
            fi
        fi
    done

    $rootdir/ldconfig >/dev/null 2>&1
}

GrpAdd() {
    AsRoot; GetRcs

    for gn in $args; do
        if [ "${gn%=*}" = "rootdir" ]; then continue; fi
        if [ "${gn}" = "reinstall" ]; then continue; fi
        if [ "${pn}" = "skipdep" ]; then continue; fi
        PkgLst
    done

    GrpDep; plst=(${deps[@]}); args=${plst[@]}; Add
}

Bld() {
    local rc_pn
    set -e

    for rc_pn in $args; do
        makepkg $rc_pn
    done

    set +e
}

GrpBld() {
    local rc_pn
    set -e

    for gn in $args; do PkgLst; done

    GrpDep

    if [ ! -d $grpdir ]; then mkdir -p $grpdir; fi

    for rc_pn in ${deps[@]}; do
        if [ ! -f $grpdir/$rc_pn ]; then
            args=($rc_pn); Bld
            if [ $? -eq 0 ]; then
                touch $grpdir/$rc_pn
            fi
        fi
    done

    set +e
}

BldDep() {
    local rc_pn
    AsRoot; GetRcs

    for rc_pn in $args; do
        if [ "${rc_pn%=*}" = "rootdir" ]; then continue; fi

        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then continue; fi

        if [ -f $rcsdir/$rc_pn/recipe ]; then
            . $rcsdir/$rc_pn/recipe
        else
            print_red "$rcsdir/$rc_pn/recipe: file not found"; exit 1
        fi

        if [ ${#pkg[@]} -ge 2 ]; then
            for i in ${!pkg[@]}; do
                _dep=($(declare -f package_${pkg[$i]} | sed -n 's/dep=\(.*\);/\1/p' | tr -d "()" | tr -d "'" | tr -d "\""))
                for i in ${_dep[@]}; do
                    if [ ! -f $rootdir/$infdir/$i ]; then
                        dlst+=($i)
                    fi
                done
            done
            if [ "${#dlst[@]}" -ge "1" ]; then
                deps+=(${dlst[@]}); unset dlst
            fi
        elif [ -n "$dep" ]; then
            for i in ${dep[@]}; do
                if [ ! -f $rootdir/$infdir/$i ]; then
                    dlst+=($i)
                fi
            done
            if [ "${#dlst[@]}" -ge "1" ]; then
                deps+=(${dlst[@]}); unset dlst
            fi
        fi

        if [ -n "$mkd" ]; then
            for i in ${mkd[@]}; do
                if [ ! -f $rootdir/$infdir/$i ]; then
                    mlst+=($i)
                fi
            done
            if [ "${#mlst[@]}" -ge "1" ]; then
                deps+=(${mlst[@]}); unset mlst
            fi
        fi
    done

    if [ "${#deps[@]}" -ge "1" ]; then
        deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))

        args=${deps[@]}; Add
    fi
}

Con() {
    tmpfile=$(mktemp /tmp/pan.XXXXXXXXXX)

    cat $lstdir/* | sort -n | uniq -d > $tmpfile
    for i in $(cat $tmpfile); do
        if [ ! -d "$i" ]; then
            if [ ! -f "$i" ]; then continue; fi
            _con=$(grep "$i" $lstdir/*)
            for ln in $_con; do
                print_red "${ln#$lstdir/}"
            done
        fi
    done

    rm $tmpfile
}

Del() {
    local rc_pn
    AsRoot

    for rc_pn in $args; do
        if [ "${rc_pn%=*}" = "rootdir" ]; then continue; fi

        if [ -f $rootdir/$infdir/$rc_pn ]; then
            . $rootdir/$infdir/$rc_pn; export pkg ver
        else
            print_red "$rootdir/$infdir/$rc_pn: file not found"; exit 1
        fi

        if [ "$grpsys" = false ]; then
            if [ -f "$rootdir/$sysdir/$pkg" ]; then
                . $rootdir/$sysdir/$pkg
                if type post_del >/dev/null 2>&1; then export -f post_del; fi
                if type post_add >/dev/null 2>&1; then export -f post_add; fi
                if (( INFAKECHROOT )); then cmd=fakechroot; fi
                if [ "$rootdir" != "/" ]; then $cmd chroot $rootdir /bin/sh -c \
                    ". $sysdir/$pkg; if type pre_del >/dev/null 2>&1; then pre_del; fi"
                else
                    if type pre_del >/dev/null 2>&1; then pre_del; fi
                fi
            fi
        fi

        if [ -f "$rootdir/$lstdir/$pkg" ]; then
            print_green "removing: $pkg ($ver-$rel)"
            list=$(tac $rootdir/$lstdir/$pkg)
        else
            continue
        fi

        for l in $list; do
            if [ -L $rootdir/$l ]; then unlink $rootdir/$l
            elif [ -f $rootdir/$l ]; then rm -f $rootdir/$l
            elif [ "$l" = "/" ]; then continue
            elif [ -d $rootdir/$l ]; then find $rootdir/$l -maxdepth 0 -type d -empty -delete
            fi
        done

        if [ "$grpsys" = false ]; then
            if (( INFAKECHROOT )); then cmd=fakechroot; fi
            if [ "$rootdir" != "/" ]; then $cmd chroot $rootdir /bin/sh -c \
                "if type post_del >/dev/null 2>&1; then post_del; fi"
            else
                if type post_del >/dev/null 2>&1; then post_del; fi
            fi
        fi

        if [ ! -d $rootdir/$logdir ]; then mkdir -p $rootdir/$logdir; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [DEL] $pkg ($ver-$rel)" >> $rootdir/$logdir/pan.log
    done

    $rootdir/ldconfig >/dev/null 2>&1
}

GrpDel() {
    local rc_pn
    AsRoot

    for gn in $args; do
        if [ "${gn%=*}" = "rootdir" ]; then continue; fi
        PkgLst
    done

    for rc_pn in ${plst[@]}; do
        if [ -f "$rootdir/$sysdir/$rc_pn" ]; then
            . $rootdir/$sysdir/$rc_pn; . $rootdir/$infdir/$rc_pn; export pkg ver
            cp $rootdir/$infdir/$rc_pn $rootdir/$infdir/$rc_pn.inf
            cp $rootdir/$sysdir/$rc_pn $rootdir/$sysdir/$rc_pn.sys
            if (( INFAKECHROOT )); then cmd=fakechroot; fi
            if [ "$rootdir" != "/" ]; then $cmd chroot $rootdir /bin/sh -c \
                ". $sysdir/$rc_pn; if type pre_del >/dev/null 2>&1; then pre_del; fi"
            else
                if type pre_del >/dev/null 2>&1; then pre_del; fi
            fi
        fi
    done

    grpsys=true; args=${plst[@]}; Del

    for rc_pn in ${plst[@]}; do
        if [ -f "$rootdir/$sysdir/$rc_pn.sys" ]; then
            . $rootdir/$sysdir/$rc_pn.sys; . $rootdir/$infdir/$rc_pn.inf; export pkg ver
            if (( INFAKECHROOT )); then cmd=fakechroot; fi
            if [ "$rootdir" != "/" ]; then $cmd chroot $rootdir /bin/sh -c \
                ". $sysdir/$rc_pn.sys; if type post_del >/dev/null 2>&1; then post_del; fi"
            else
                if type post_del >/dev/null 2>&1; then post_del; fi
            fi
            rm -f $rootdir/$sysdir/$rc_pn.sys $rootdir/$infdir/$rc_pn.inf
        fi
    done
}

Grp() {
    GetRcs; PkgLst

    echo "${plst[@]}"
}

GrpLst() {
    local rc_pn
    GetRcs

    for rc_pn in $(ls $rcsdir); do
        if [ -f $rcsdir/$rc_pn/recipe ]; then
            . $rcsdir/$rc_pn/recipe
        fi

        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then
            unset pkg grp; continue
        fi

        if [ ${#pkg[@]} -ge 2 ]; then
            for i in ${!pkg[@]}; do
                grp=$(echo $(declare -f package_${pkg[$i]} | sed -n 's/grp=\(.*\);/\1/p'))
                glst+=($grp)
            done
        else
            glst+=($grp)
        fi
        unset pkg grp
    done

    glst=($(echo ${glst[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
    echo "${glst[@]}"
}

Inf() {
    if [ -f $infdir/$pn ]; then
        . $infdir/$pn

        print_green "package: $pkg"
        print_green "version: $ver"
        print_green "release: $rel"
        if [ -n "$grp" ]; then
            print_green "section: $grp"
        fi
        if [ "${#dep[@]}" -ge "1" ]; then
            print_green "depends: ${dep[*]}"
        fi
        if [ -n "$src" ]; then
            if [ "${#src[@]}" -gt "1" ]; then
                for src_url in ${src[@]}; do
                    if [[ $src_url =~ "::" ]]; then src_url=${src_url#*::}; fi
                    print_green "sources: $src_url"
                done
            else
                if [[ $src =~ "::" ]]; then src=${src#*::}; fi
                print_green "sources: $src"
            fi
        fi
    else
        if [ -n "$pn" ]; then
            print_red "$infdir/$pn: file not found"
        fi
    fi
}

Lst() {
    if [ -n "$pn" ]; then
        if [ -f $lstdir/$pn ]; then
            cat $lstdir/$pn
        else
            print_red "$lstdir/$pn: file not found"
        fi
    fi
}

Own() {
    if [ -n "$pt" ]; then
        _own=$(grep "$pt" $lstdir/*)
        for ln in $_own; do
            if [ "$pt" = "${ln#*:}" ]; then
                print_green "${ln#$lstdir/}"
            fi
        done
    fi
}

Sha() {
    local shaxxxsum=sha256sum
    if [ -n "$pn" ]; then
        if [ -f $rcsdir/$pn/recipe ]; then
            . $rcsdir/$pn/recipe
        else
            print_red "$rcsdir/$pn/recipe: file not found"
        fi

        for src_url in ${src[@]}; do
            if [[ $src_url =~ "::" ]]; then
                file=${src_url%::*}; src_url=${src_url#*::}
            else
                file=$(basename $src_url)
            fi
            if [ ! -f $tmpdir/$file ]; then
                print_green "downloading: $file"
                curl -L -o $tmpdir/$file $src_url
            fi
            shasum+=$(echo "$(sha256sum $tmpdir/$file | cut -d' ' -f1) ")
        done

        for _sum in ${shasum[@]}; do
            echo $_sum
        done
    fi
}

Upd() {
    local rc_pn deps

    AsRoot

    if [ "$updrcs" = true ]; then
        if [ -d $rcsdir ]; then
            cd $rcsdir; git pull origin master
        else
            GetRcs
        fi
    fi

    if [ -z "$args" ]; then return 0; fi

    for rc_pn in $args; do
        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then
            if [ -f $rcsdir/$rc_pn/recipe ]; then
                . $rcsdir/$rc_pn/recipe
                pkg=$rc_pn; ver1=$ver; rel1=$rel; unset ver rel
            else
                print_red "$rcsdir/$rc_pn/recipe: file not found"; exit 1
            fi
        else
            if [ -f $rcsdir/$rc_pn/recipe ]; then
                . $rcsdir/$rc_pn/recipe
                ver1=$ver; rel1=$rel; unset ver rel
            else
                print_red "$rcsdir/$rc_pn/recipe: file not found"; exit 1
            fi
        fi

        if [ -f $infdir/$pkg ]; then
            . $infdir/$pkg
            ver2=$ver; rel2=$rel; unset ver rel
        else
            continue
        fi

        ver=$(echo -e "$ver1\n$ver2" | sort -V | tail -n1)
        rel=$(echo -e "$rel1\n$rel2" | sort -V | tail -n1)

        if [ "$ver1" != "$ver2" ]; then
            if [ "$ver1" = "$ver" ]; then
                ulst+=($pkg)
            fi
        elif [ "$ver1" = "$ver2" ]; then
            if [ "$rel1" != "$rel2" ]; then
                if [ "$rel1" = "$rel" ]; then
                    ulst+=($pkg)
                fi
            fi
        fi
    done

    unset pkg

    for rc_pn in ${ulst[@]}; do
        . $rcsdir/$rc_pn/recipe;
        GetDep $pkg; deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
        for i in ${deps[@]}; do
            if [ ! -f "$rootdir/$infdir/$i" ]; then missing_deps+=($i); fi
        done
    done

    missing_deps=($(echo ${missing_deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
    args=${missing_deps[@]}; Add

    plst=(${ulst[@]}); GetPkg; ChkSha

    for rc_pn in ${ulst[@]}; do
        . $infdir/$rc_pn
        _ver=$ver; _rel=$rel; unset ver rel
        . $rcsdir/$rc_pn/recipe
        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then pkg=$rc_pn; fi

        print_green "updating: $pkg ($_ver-$_rel -> $ver-$rel)"

        if [ -f "$sysdir/$pkg" ]; then . $sysdir/$pkg
            if type pre_upd >/dev/null 2>&1; then pre_upd; fi
        fi

        rn=$lstdir/$pkg; cp $rn $rn.bak

        backup
        tar -C $rootdir -xpf $arcdir/$pkg-$ver-$rel.$ext
        restore
        unset bak

        tmpfile=$(mktemp /tmp/pan.XXXXXXXXXX)
        list=$(comm -23 <(sort $rn.bak) <(sort $rn))
        for l in $list; do
            echo $l >> $tmpfile
        done
        list=$(tac $tmpfile)

        for l in $list; do
            if [ -L $l ]; then unlink $l
            elif [ -f $l ]; then rm -f $l
            elif [ "$l" = "/" ]; then continue
            elif [ -d $l ]; then find $l -maxdepth 0 -type d -empty -delete
            fi
        done

        rm $rn.bak $tmpfile

        if [ -f "$sysdir/$pkg" ]; then . $sysdir/$pkg
            if type post_upd >/dev/null 2>&1; then post_upd; fi
        fi

        if [ ! -d $rootdir/$logdir ]; then mkdir -p $rootdir/$logdir; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [UPD] $pkg ($ver-$rel)" >> $logdir/pan.log
    done

    $rootdir/ldconfig >/dev/null 2>&1
}

reduceupds() {
    for array in ${_ulst[@]}; do
        if [[ " ${deps[*]} " =~ " $array " ]]; then continue
        else slst+=($array)
        fi
    done
}

GrpUpd() {
    local rc_pn

    AsRoot

    if [ -d $rcsdir ]; then
        cd $rcsdir; git pull origin master
    else
        GetRcs
    fi

    if [ -n "$args" ]; then
        for gn in ${args[@]}; do PkgLst; done
        GrpDep; _ulst=(${deps[@]})
    else
        for rc_pn in $(ls $rcsdir); do
            if [ -f $rcsdir/$rc_pn/recipe ]; then
               . $rcsdir/$rc_pn/recipe
            fi
            if [ ${#pkg[@]} -ge 2 ]; then
                for i in ${!pkg[@]}; do
                    plst+=(${pkg[$i]})
                done
            else
                plst+=($pkg)
            fi
        done
        _ulst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
    fi

    if [ -n "$skipupd" ]; then
        unset plst deps
        for gn in ${skipupd[@]}; do PkgLst; done
        GrpDep; reduceupds; _ulst=(${slst[@]})
    fi

    unset plst deps
    updrcs=false; args=${_ulst[@]}; Upd
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
            echo "  -m, --make-deps <name>          add build dependencies"
            echo "  -o, --owner <path>              show the file ownership"
            echo "  -s, --sha-hash <name>           generate SHA hash"
            echo "  -u, --update <name>             update a package"
            echo "  -U, --update-all (groupname)    update all the packages"
            echo "options:"
            echo "  reinstall                       force add a package"
            echo "  rootdir=<directory>             change root directory"
            echo "  skipdep                         skip dependency resolution"
            exit 1;;
        reinstall) reinst=true;;
        rootdir=*) rootdir=${i#*=};;
        skipdep) skipdep=true;;
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
        -m|--make-deps) _BldDep=true;;
        -o|--owner) _Own=true;;
        -s|--shasum) _Sha=true;;
        -u|--update) _Upd=true;;
        -U|--update-all) _GrpUpd=true;;
    esac
done

if [ "$_Add" = true ]; then shift; args=$@; Add; fi
if [ "$_GrpAdd" = true ]; then shift; args=$@; GrpAdd; fi
if [ "$_Bld" = true ]; then shift; args=$@; Bld; fi
if [ "$_GrpBld" = true ]; then shift; args=$@; GrpBld; fi
if [ "$_BldDep" = true ]; then shift; args=$@; BldDep; fi
if [ "$_Con" = true ]; then shift; Con; fi
if [ "$_Del" = true ]; then shift; args=$@; Del; fi
if [ "$_GrpDel" = true ]; then shift; args=$@; GrpDel; fi
if [ "$_Grp" = true ]; then shift; gn=$1; Grp; fi
if [ "$_GrpLst" = true ]; then shift; GrpLst; fi
if [ "$_Inf" = true ]; then shift; pn=$1; Inf; fi
if [ "$_Lst" = true ]; then shift; pn=$1; Lst; fi
if [ "$_Own" = true ]; then shift; pt=$1; Own; fi
if [ "$_Sha" = true ]; then shift; pn=$1; Sha; fi
if [ "$_Upd" = true ]; then shift; args=$@; Upd; fi
if [ "$_GrpUpd" = true ]; then shift; args=$@; GrpUpd; fi