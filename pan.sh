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
_Upd=false
_GrpUpd=false
grpsys=false
updrcs=true
reinst=false
skipdep=false

AsRoot() {
    if [[ ${EUID} -ne 0 ]] && [ "$rootdir" = "/" ]; then
        echo "This script must be run as root."
        exit 1
    fi
}

SetPrm() {
    chgrp -R users $1
    chmod -R g+w $1
}

GetRcs() {
    if [ ! -d $rcsdir ]; then
        git clone $rcsrepo $rcsdir; SetPrm $rcsdir
    fi
}

PkgLst() {
    local rc_pn
    for rc_pn in $(ls $rcsdir); do
        if [ -f $rcsdir/$rc_pn/recipe ]; then
            . $rcsdir/$rc_pn/recipe
        fi

        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then
            unset n v r g d u b o; continue
        fi

        if [ ${#n[@]} -ge 2 ]; then
            for i in ${!n[@]}; do
                g=$(echo $(declare -f package_${n[$i]} | sed -n 's/g=\(.*\);/\1/p'))
                if [ -z "$g" ]; then continue; fi
                if [ "$g" = "$gn" ]; then plst+=(${n[$i]}); fi
                if [ -n "$g" ]; then _plst+=(${n[$i]}); fi
            done
        else
            if [ -z "$g" ]; then unset n v g d u b o; continue; fi
            if [ "$g" = "$gn" ]; then plst+=($n); fi
            if [ -n "$g" ]; then _plst+=($n); fi
        fi
        unset n v r g d u b o
    done

    plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
    _plst=($(for i in ${_plst[@]}; do echo $i; done | sort -u))
}

reducedeps() {
    for array in ${_plst[@]}; do
        if [[ " ${plst[*]} " =~ " $array " ]]; then continue
        else __plst+=($array)
        fi
    done

    for array in ${deps[@]}; do
        if [[ " ${__plst[*]} " =~ " $array " ]]; then continue
        else __deps+=($array)
        fi
    done
    deps=(${__deps[@]})
}

reduceupds() {
    for array in ${_ulst[@]}; do
        if [[ " ${slst[*]} " =~ " $array " ]]; then continue
        else __slst+=($array)
        fi
    done
}

GetPkg() {
    local rc_pn rc_pn_missing
    for rc_pn in ${plst[@]}; do
        . $rcsdir/$rc_pn/recipe
        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then n=$rc_pn; fi
        if [ ! -f $arcdir/$n-$v-$r.$pkgext ]; then
            echo "downloading: $n-$v-$r.$pkgext"
            curl -f -L -o $arcdir/$n-$v-$r.$pkgext $getpkg/$n-$v-$r.$pkgext
            if [ ! -f $arcdir/$n-$v-$r.$pkgext ]; then
                echo "$n: archive file not found"
                rc_pn_missing+=($n)
            fi
        fi
    done

    if [ "${#rc_pn_missing[@]}" -ge "1" ]; then
        echo "missing archive(s): ${rc_pn_missing[@]}"; exit 1
    fi

    unset n v r g d u b o
}

RtDeps() {
    local rc_pn=$1 dep
    if [ -f $rcsdir/$rc_pn/recipe ]; then
        . $rcsdir/$rc_pn/recipe
    fi

    if [ ${#n[@]} -ge 2 ]; then
        for i in ${!n[@]}; do
            if [ "${n[$i]}" = "$rc_pn" ]; then
                d=($(declare -f package_${n[$i]} | sed -n 's/d=\(.*\);/\1/p' | tr -d "()" | tr -d "'" | tr -d "\""))
            fi
        done
        unset n
    fi

    deps=(${deps[@]} $1)
    for dep in ${d[@]}; do
        if [[ " ${deps[*]} " =~ " $dep " ]]; then
            continue
        else
            deps=(${deps[@]} $dep)
            RtDeps $dep
        fi
    done
}

GrpDep() {
    local rc_pn
    for rc_pn in ${plst[@]}; do
        RtDeps $rc_pn
    done
    unset n v r g d u b o
 
    deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

backup() {
    if [ -n "$b" ]; then
        for _f in ${b[@]}; do
            if [ -f $rootdir/$_f ]; then
                cp $rootdir/$_f $rootdir/${_f}.bak
            fi
        done
    fi
}

restore() {
    if [ -n "$b" ]; then
        for _f in ${b[@]}; do
            if [ -f $rootdir/${_f}.bak ]; then
                cp $rootdir/$_f $rootdir/${_f}.new
                mv $rootdir/${_f}.bak $rootdir/$_f
            fi
        done
    fi
}

Add() {
    local rc_pn dep deps
    AsRoot; GetRcs

    for rc_pn in $args; do
        if [ "${rc_pn%=*}" = "rootdir" ]; then continue; fi
        if [ "${rc_pn}" = "reinstall" ]; then continue; fi
        if [ "${rc_pn}" = "skipdep" ]; then continue; fi

        if [ -f $rcsdir/$rc_pn/recipe ]; then
            . $rcsdir/$rc_pn/recipe
        else
            echo "$rc_pn: recipe file not found"; exit 1
        fi
        alst+=($rc_pn)
        if [ "$skipdep" = true ]; then deps+=($rc_pn); else RtDeps $rc_pn; fi
    done

    deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))

    for dep in ${deps[@]}; do
        if [ ! -f $rcsdir/$dep/recipe ]; then
            missing_deps+=($dep); echo "$dep: recipe file not found"
        else
            if [ -f "$rootdir/$infdir/$dep" ]; then
                for pn in ${alst[@]}; do
                    if [ "$dep" = "$rc_pn" ] && [ "$reinst" = true ]; then
                        _deps+=($dep)
                    else
                        continue
                    fi
                done
                continue
            else
               _deps+=($dep)
            fi
        fi
    done

    if [ "${#missing_deps[@]}" -ge "1" ]; then
        echo "missing deps: ${missing_deps[@]}"; exit 1
    fi

    plst=(${_deps[@]}); GetPkg

    for dep in ${_deps[@]}; do
        . $rcsdir/$dep/recipe
        if  [[ -L "$rcsdir/$dep" && -d "$rcsdir/$dep" ]]; then n=$dep; fi

        echo "installing: $n ($v-$r)"
        backup
        tar -C $rootdir -xpf $arcdir/$n-$v-$r.$pkgext
        chmod 777 $rootdir/pkg &>/dev/null
        restore
        unset b

        if [ ! -d $rootdir/$logdir ]; then mkdir -p $rootdir/$logdir; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [ADD] $n ($v-$r)" >> $rootdir/$logdir/add
    done

    for dep in ${_deps[@]}; do
        . $rcsdir/$dep/recipe
        if  [[ -L "$rcsdir/$dep" && -d "$rcsdir/$dep" ]]; then n=$dep; fi
        export n v
        if [ -f "$rootdir/$sysdir/$n" ]; then . $rootdir/$sysdir/$n
            if [ "$rootdir" != "/" ]; then chroot $rootdir /bin/sh -c \
                ". $sysdir/$n; if type post_add >/dev/null 2>&1; then post_add; fi"
            else
                if type post_add >/dev/null 2>&1; then post_add; fi
            fi
        fi
    done
}

GrpAdd() {
    AsRoot; GetRcs

    for gn in $args; do
        if [ "${gn%=*}" = "rootdir" ]; then continue; fi
        if [ "${gn}" = "reinstall" ]; then continue; fi
        if [ "${pn}" = "skipdep" ]; then continue; fi
        PkgLst
    done

    GrpDep; reducedeps; plst=(${deps[@]})
    GetPkg; skipdep=true; args=${plst[@]}; Add
}

Bld() {
    local rc_pn
    for rc_pn in $args; do
        makepkg $rc_pn
    done
}

GrpBld() {
    local rc_pn

    for gn in $args; do PkgLst; done

    GrpDep; reducedeps

    if [ ! -d $grpdir ]; then mkdir -p $grpdir; fi

    for rc_pn in ${deps[@]}; do
        if [ ! -f $grpdir/$rc_pn ]; then
            args=($rc_pn); Bld
            if [ $? -eq 0 ]; then
                touch $grpdir/$rc_pn
            fi
        fi
    done
}

BldDep() {
    local rc_pn
    GetRcs

    for rc_pn in $args; do
        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then continue; fi

        if [ -f $rcsdir/$rc_pn/recipe ]; then
            . $rcsdir/$rc_pn/recipe
        else
            echo "$rc_pn: recipe file not found"; exit 1
        fi

        if [ ${#n[@]} -ge 2 ]; then
            for i in ${!n[@]}; do
                _d=($(declare -f package_${n[$i]} | sed -n 's/d=\(.*\);/\1/p' | tr -d "()" | tr -d "'" | tr -d "\""))
                for dep in ${_d[@]}; do
                    if [ ! -f $infdir/$dep ]; then
                        dlst+=($dep)
                    fi
                done
            done
            if [ "${#dlst[@]}" -ge "1" ]; then
                deps+=(${dlst[@]}); dlst=
            fi
        elif [ -n "$d" ]; then
            for dep in ${d[@]}; do
                if [ ! -f $infdir/$dep ]; then
                    dlst+=($dep)
                fi
            done
            if [ "${#dlst[@]}" -ge "1" ]; then
                deps+=(${dlst[@]}); dlst=
            fi
        fi

        if [ -n "$m" ]; then
            for dep in ${m[@]}; do
                if [ ! -f $infdir/$dep ]; then
                    mlst+=($dep)
                fi
            done
            if [ "${#mlst[@]}" -ge "1" ]; then
                deps+=(${mlst[@]}); mlst=
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
                echo "${ln#$lstdir/}"
            done
        fi
    done

    rm $tmpfile
}

Del() {
    local rc_pn
    AsRoot

    for rc_pn in $args; do
        if [ "${pn%=*}" = "rootdir" ]; then continue; fi

        if [ -f $rootdir/$infdir/$rc_pn ]; then
            . $rootdir/$infdir/$rc_pn; export n v
        else
            echo "$rc_pn: info file not found"; exit 1
        fi

        if [ "$grpsys" = false ]; then
            if [ -f "$rootdir/$sysdir/$n" ]; then
                . $rootdir/$sysdir/$n
                if type post_del >/dev/null 2>&1; then export -f post_del; fi
                if type post_add >/dev/null 2>&1; then export -f post_add; fi
                if [ "$rootdir" != "/" ]; then chroot $rootdir /bin/sh -c \
                    ". $sysdir/$n; if type pre_del >/dev/null 2>&1; then pre_del; fi"
                else
                    if type pre_del >/dev/null 2>&1; then pre_del; fi
                fi
            fi
        fi

        if [ -f "$rootdir/$lstdir/$n" ]; then
            echo "removing: $n ($v-$r)"
            list=$(tac $rootdir/$lstdir/$n)
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
            if [ "$rootdir" != "/" ]; then chroot $rootdir /bin/sh -c \
                "if type post_del >/dev/null 2>&1; then post_del; fi"
            else
                if type post_del >/dev/null 2>&1; then post_del; fi
            fi
        fi

        if [ ! -d $rootdir/$logdir ]; then mkdir -p $rootdir/$logdir; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [DEL] $n ($v-$r)" >> $rootdir/$logdir/del
    done
}

GrpDel() {
    local rc_pn
    AsRoot

    for gn in $args; do
        if [ "${gn%=*}" = "rootdir" ]; then continue; fi

        for rc_pn in $(ls $rootdir/$infdir); do
            if [ -f $rootdir/$infdir/$rc_pn ]; then
                . $rootdir/$infdir/$rc_pn
            fi
 
            if [ "$g" = "$gn" ]; then plst+=($n); fi
        done

        plst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
    done

    for rc_pn in ${plst[@]}; do
        if [ -f "$rootdir/$sysdir/$rc_pn" ]; then
            . $rootdir/$sysdir/$rc_pn; . $rootdir/$infdir/$rc_pn; export n v
            cp $rootdir/$infdir/$rc_pn $rootdir/$infdir/$rc_pn.inf
            cp $rootdir/$sysdir/$rc_pn $rootdir/$sysdir/$rc_pn.sys
            if [ "$rootdir" != "/" ]; then chroot $rootdir /bin/sh -c \
                ". $sysdir/$rc_pn; if type pre_del >/dev/null 2>&1; then pre_del; fi"
            else
                if type pre_del >/dev/null 2>&1; then pre_del; fi
            fi
        fi
    done

    grpsys=true; args=${plst[@]}; Del

    for rc_pn in ${plst[@]}; do
        if [ -f "$rootdir/$sysdir/$rc_pn.sys" ]; then
            . $rootdir/$sysdir/$rc_pn.sys; . $rootdir/$infdir/$rc_pn.inf; export n v
            if [ "$rootdir" != "/" ]; then chroot $rootdir /bin/sh -c \
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
            unset n s; continue
        fi

        if [ ${#n[@]} -ge 2 ]; then
            for i in ${!n[@]}; do
                g=$(echo $(declare -f package_${n[$i]} | sed -n 's/g=\(.*\);/\1/p'))
                glst+=($g)
            done
        else
            glst+=($g)
        fi
        unset n g
    done

    glst=($(echo ${glst[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
    echo "${glst[@]}"
}

Inf() {
    if [ -f $infdir/$pn ]; then
        . $infdir/$pn

        echo "program: $n"
        echo "version: $v"
        echo "release: $r"
        if [ -n "$g" ]; then
            echo "section: $g"
        fi
        if [ "${#d[@]}" -ge "1" ]; then
            echo "depends: ${d[@]}"
        fi
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
        if [ -f $lstdir/$pn ]; then
            cat $lstdir/$pn
        else
            echo "$pn: filelist not found"
        fi
    fi
}

Own() {
    if [ -n "$pt" ]; then
        _own=$(grep "$pt" $lstdir/*)
        for ln in $_own; do
            if [ "$pt" = "${ln#*:}" ]; then
                echo "${ln#$lstdir/}"
            fi
        done
    fi
}

Upd() {
    local rc_pn deps
    if [ "$updrcs" = true ]; then
        if [ -d $rcsdir ]; then
            cd $rcsdir; git pull origin master; SetPrm $rcsdir
        else
            GetRcs
        fi
    fi

    for rc_pn in $args; do
        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then
            if [ -f $rcsdir/$rc_pn/recipe ]; then
                . $rcsdir/$rc_pn/recipe; n=$rc_pn; v1=$v; r1=$r; v=; r=
            else
                echo "$rc_pn: recipe file not found"
            fi
        else
            if [ -f $rcsdir/$rc_pn/recipe ]; then
                . $rcsdir/$rc_pn/recipe; v1=$v; r1=$r; v=; r=
            else
                echo "$rc_pn: recipe file not found"
            fi
        fi

        if [ -f $infdir/$n ]; then
            . $infdir/$n; v2=$v; r2=$r; v=; r=
        else
            continue
        fi

        v=$(echo -e "$v1\n$v2" | sort -V | tail -n1)
        r=$(echo -e "$r1\n$r2" | sort -V | tail -n1)

        if [ "$v1" != "$v2" ]; then
            if [ "$v1" = "$v" ]; then
                ulst+=($n)
            fi
        elif [ "$v1" = "$v2" ]; then
            if [ "$r1" != "$r2" ]; then
                if [ "$r1" = "$r" ]; then
                    ulst+=($n)
                fi
            fi
        fi
    done

    unset n

    for rc_pn in ${ulst[@]}; do
        . $rcsdir/$rc_pn/recipe;
        RtDeps $n; deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
        for dep in ${deps[@]}; do
            if [ ! -f "$rootdir/$infdir/$dep" ]; then missing deps+=($dep); fi
        done
    done

    missing_deps=($(echo ${missing_deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
    args=${missing_deps[@]}; Add

    plst=(${ulst[@]}); GetPkg

    for rc_pn in ${ulst[@]}; do
        . $infdir/$rc_pn; _v=$v; _r=$r
        . $rcsdir/$rc_pn/recipe
        if  [[ -L "$rcsdir/$rc_pn" && -d "$rcsdir/$rc_pn" ]]; then n=$rc_pn; fi

        echo "updating: $n ($_v-$_r -> $v-$r)"

        if [ -f "$sysdir/$n" ]; then . $sysdir/$n
            if type pre_upd >/dev/null 2>&1; then pre_upd; fi
        fi

        rn=$lstdir/$n; cp $rn $rn.bak

        backup
        tar -C $rootdir -xpf $arcdir/$n-$v-$r.$pkgext
        chmod 777 $rootdir/pkg &>/dev/null
        restore
        unset b

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

        if [ -f "$sysdir/$n" ]; then . $sysdir/$n
            if type post_upd >/dev/null 2>&1; then post_upd; fi
        fi

        if [ ! -d $rootdir/$logdir ]; then mkdir -p $rootdir/$logdir; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [UPD] $n ($v-$r)" >> $logdir/upd
    done
}

GrpUpd() {
    local rc_pn
    if [ -d $rcsdir ]; then
        cd $rcsdir; git pull origin master; SetPrm $rcsdir
    else
        GetRcs
    fi

    if [ -n "$args" ]; then
        for gn in ${args[@]}; do PkgLst; done
        GrpDep; reducedeps; _ulst=(${deps[@]})
    else
        for rc_pn in $(ls $rcsdir); do
            if [ -f $rcsdir/$rc_pn/recipe ]; then
               . $rcsdir/$rc_pn/recipe
            fi
            if [ ${#n[@]} -ge 2 ]; then
                for i in ${!n[@]}; do
                    plst+=(${n[$i]})
                done
            else
                plst+=($n)
            fi
        done
        _ulst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
    fi

    if [ -n "$skipupd" ]; then
        plst=(); _plst=(); deps=()
        for gn in ${skipupd[@]}; do PkgLst; done
        GrpDep; slst=(${plst[@]}); reduceupds; _ulst=(${__slst[@]})
    fi

    plst=(); _plst=()
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
            echo "  -u, --update <name>             update a package"
            echo "  -U, --update-all (groupname)    update all the packages"
            echo "options:"
            echo "  reinstall                       force add a package"
            echo "  rootdir=<directory>                change root directory"
            echo "  skipdep                         skip dependency resolution"
            exit 1;;
        reinstall) reinst=true;;
        rootdir=*)
            rootdir=${i#*=};;
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
if [ "$_Upd" = true ]; then shift; args=$@; Upd; fi
if [ "$_GrpUpd" = true ]; then shift; args=$@; GrpUpd; fi