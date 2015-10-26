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
    if [[ ${EUID} -ne 0 ]] && [ "$root" = "/" ]; then
        echo "This script must be run as root."
        exit 1
    fi
}

SetPrm() {
    chgrp -R users $1
    chmod -R g+w $1
}

GetRcs() {
    if [ ! -d $rcs ]; then
        git clone $gitrcs $rcs; SetPrm $rcs
    fi
}

PkgLst() {
    for _pkg in $(ls $rcs); do
        if [ -f $rcs/$_pkg/recipe ]; then
            . $rcs/$_pkg/recipe
        fi

        if  [[ -L "$rcs/$_pkg" && -d "$rcs/$_pkg" ]]; then
            unset n v r g d u b o; continue
        fi

        if [ ${#n[@]} -ge 2 ]; then
            for i in ${!n[@]}; do
                s=$(echo $(declare -f package_${n[$i]} | sed -n 's/s=\(.*\);/\1/p'))
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

    unset _pkg
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
    for _pkg in ${plst[@]}; do
        . $rcs/$_pkg/recipe
        if  [[ -L "$rcs/$_pkg" && -d "$rcs/$_pkg" ]]; then n=$_pkg; fi
        if [ ! -f $arc/$n-$v-$r.$pkgext ]; then
            echo "downloading: $n-$v-$r.$pkgext"
            curl -f -L -o $arc/$n-$v-$r.$pkgext $getpkg/$n-$v-$r.$pkgext
            if [ ! -f $arc/$n-$v-$r.$pkgext ]; then
                echo "$n: archive file not found"
                _pkg_+=($n)
            fi
        fi
    done

    if [ "${#_pkg_[@]}" -ge "1" ]; then
        echo "missing archive(s): ${_pkg_[@]}"; exit 1
    fi

    unset _pkg n v r g d u b o
}

RtDeps() {
    if [ -f $rcs/$1/recipe ]; then
        . $rcs/$1/recipe
    fi

    if [ ${#n[@]} -ge 2 ]; then
        for i in ${!n[@]}; do
            if [ "${n[$i]}" = "$1" ]; then
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
    for _pkg_ in ${plst[@]}; do
        RtDeps $_pkg_
    done
    unset _pkg_ n v r g d u b o
 
    deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
}

backup() {
    if [ -n "$b" ]; then
        for _f in ${b[@]}; do
            if [ -f $root/$_f ]; then
                cp $root/$_f $root/${_f}.bak
            fi
        done
    fi
}

restore() {
    if [ -n "$b" ]; then
        for _f in ${b[@]}; do
            if [ -f $root/${_f}.bak ]; then
                cp $root/$_f $root/${_f}.new
                mv $root/${_f}.bak $root/$_f
            fi
        done
    fi
}

Add() {
    AsRoot; GetRcs

    for pn in $args; do
        if [ "${pn%=*}" = "root" ]; then continue; fi
        if [ "${pn}" = "reinstall" ]; then continue; fi
        if [ "${pn}" = "skipdep" ]; then continue; fi

        if [ -f $rcs/$pn/recipe ]; then
            . $rcs/$pn/recipe
        else
            echo "$pn: recipe file not found"; exit 1
        fi
        alst+=($pn)
        if [ "$skipdep" = true ]; then deps+=($pn); else RtDeps $pn; fi
    done

    deps=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))

    for dep in ${deps[@]}; do
        if [ ! -f $rcs/$dep/recipe ]; then
            mdeps+=($dep); echo "$dep: recipe file not found"
        else
            if [ -f "$root/$inf/$dep" ]; then
                for pn in ${alst[@]}; do
                    if [ "$dep" = "$pn" ] && [ "$reinst" = true ]; then
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

    if [ "${#mdeps[@]}" -ge "1" ]; then
        echo "missing deps: ${mdeps[@]}"; exit 1
    fi

    plst=(${_deps[@]}); GetPkg

    for dep in ${_deps[@]}; do
        . $rcs/$dep/recipe
        if  [[ -L "$rcs/$dep" && -d "$rcs/$dep" ]]; then n=$dep; fi

        echo "installing: $n ($v-$r)"
        backup
        tar -C $root -xpf $arc/$n-$v-$r.$pkgext
        chmod 777 $root/pkg &>/dev/null
        restore
        unset b

        if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [ADD] $n ($v-$r)" >> $root/$log/add
    done

    for dep in ${_deps[@]}; do
        . $rcs/$dep/recipe
        if  [[ -L "$rcs/$dep" && -d "$rcs/$dep" ]]; then n=$dep; fi
        export n v
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
    AsRoot; GetRcs

    for gn in $args; do
        if [ "${gn%=*}" = "root" ]; then continue; fi
        if [ "${gn}" = "reinstall" ]; then continue; fi
        if [ "${pn}" = "skipdep" ]; then continue; fi
        PkgLst
    done

    GrpDep; reducedeps; plst=(${deps[@]})
    GetPkg; skipdep=true; args=${plst[@]}; Add
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
        git clone $_giturl $src/$n-$v
        pushd $src/$n-$v &>/dev/null
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
    fi
}

extract() {
    if [[ $1 != git* ]]; then
        if [ "$NoExtract" = false ]; then
            echo "extracting: $file"
            local cmd="--strip-components=1"
            case $file in
                *.tar.bz2)
                    tar -C $src/$n-$v -jxpf $tmp/$file $cmd;;
                *.tar.xz|*.tar.gz|*.tgz|*.tar)
                    tar -C $src/$n-$v -xpf $tmp/$file $cmd;;
                *.bz2|*.gz|*.zip)
                    bsdtar -C $src/$n-$v -xpf $tmp/$file $cmd;;
                *) echo "$file: archive not supported";;
            esac
        fi
    fi
}

_package() {
    cd $pkg; mkdir -p $pkg/{$inf,$lst}
    echo "n=$n" >> $pkg/$inf/$n
    echo "v=$v" >> $pkg/$inf/$n
    echo "r=$r" >> $pkg/$inf/$n
    echo "g=$g" >> $pkg/$inf/$n
    printf "%s " "d=(${d[@]})" >> $pkg/$inf/$n
    echo -e "" >> $pkg/$inf/$n
    printf "%s " "u=(${u[@]})" >> $pkg/$inf/$n
    echo -e "" >> $pkg/$inf/$n

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

    if [ "$NoEmptyDirs" = true ]; then
        touch $pkg/$lst/$n
        find . -type d -empty -delete
    fi

    find ./ | sed 's/.\//\//' | sort > $pkg/$lst/$n

    fakeroot -i $src/state.$n -- tar -cpJf $bld/arc/$n-$v-$r.$pkgext ./
}

Bld() {
    set -e

    GetRcs

    for pn in $args; do
        NoEmptyDirs=false; NoExtract=false; NoStrip=false

        if  [[ -L "$rcs/$pn" && -d "$rcs/$pn" ]]; then continue; fi

        if [ -f $rcs/$pn/recipe ]; then
            . $rcs/$pn/recipe
        else
            echo "$pn: recipe file not found"; exit 1
        fi

        _rcs=$rcs; _pkg=$pkg; _pwd=`pwd`
        mkdir -p $bld/arc $src/$n-$v $tmp

        for opt in "${o[@]}"; do
            if [ "$opt" = "noemptydirs" ]; then NoEmptyDirs=true; fi
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
        fi

        echo "building: $n ($v)"
        if [ -d "$src/$n-$v" ]; then cd $src/$n-$v; else cd $src; fi

        tmpfile=$(mktemp /tmp/$n.XXXXXXXXXX)

        cp $rcs/$n/recipe $tmpfile  
        sed -i -e "s#build() {#build() {\n    set -e#" $tmpfile

        if [ ${#n[@]} -ge 2 ]; then
            for i in ${!n[@]}; do
                sed -i -e "s#package_${n[$i]}() {#package_${n[$i]}() {\n    set -e#" $tmpfile
            done
        else
            sed -i -e "s#package() {#package() {\n    set -e#" $tmpfile
        fi

        . $tmpfile; rcs=$rcs/$n

        export CHOST CFLAGS CXXFLAGS LDFLAGS MAKEFLAGS pkg rcs src tmp n v u

        if type build >/dev/null 2>&1; then build; fi

        if [ ${#n[@]} -ge 2 ]; then
            for i in ${!n[@]}; do
                n=${n[$i]}; _pwd_=`pwd`
                pkg=$pkg/$n; mkdir -p $pkg
                s=$(echo $(declare -f package_$n | sed -n 's/s=\(.*\);/\1/p'))
                d=($(declare -f package_$n | sed -n 's/d=\(.*\);/\1/p' | tr -d "()" | tr -d "'" | tr -d "\""))

                export -f package_$n; fakeroot -s $src/state.$n package_$n

                if [ -f "$rcs/system.$n" ]; then
                    mkdir -p $pkg/$sys; cp $rcs/system.$n $pkg/$sys/$n
                fi

                _package; pkg=$_pkg; cd $_pwd_
            done
            n=(); cd $_pwd
        else
            pkg=$pkg/$n; mkdir -p $pkg

            export -f package; fakeroot -s $src/state.$n package

            if [ -f "$rcs/system" ]; then
                mkdir -p $pkg/$sys; cp $rcs/system $pkg/$sys/$n
            fi

            _package; cd $_pwd
        fi

        rm -rf $_pkg $src $tmpfile
        rcs=$_rcs; pkg=$_pkg; o=(); u=(); unset -f build
    done
}

GrpBld() {
    set -e

    GetRcs

    for gn in $args; do PkgLst; done

    GrpDep; reducedeps

    if [ ! -d $grp ]; then mkdir -p $grp; fi

    for _pkg_ in ${deps[@]}; do
        if [ ! -f $grp/$_pkg_ ]; then
            args=($_pkg_); Bld
            if [ $? -eq 0 ]; then
                touch $grp/$_pkg_
            fi
        fi
    done
}

BldDep() {
    GetRcs

    for pn in $args; do
        if  [[ -L "$rcs/$pn" && -d "$rcs/$pn" ]]; then continue; fi

        if [ -f $rcs/$pn/recipe ]; then
            . $rcs/$pn/recipe
        else
            echo "$pn: recipe file not found"; exit 1
        fi

        if [ ${#n[@]} -ge 2 ]; then
            for i in ${!n[@]}; do
                _d=($(declare -f package_${n[$i]} | sed -n 's/d=\(.*\);/\1/p' | tr -d "()" | tr -d "'" | tr -d "\""))
                for dep in ${_d[@]}; do
                    if [ ! -f $inf/$dep ]; then
                        dlst+=($dep)
                    fi
                done
            done
            if [ "${#dlst[@]}" -ge "1" ]; then
                deps+=(${dlst[@]}); dlst=
            fi
        elif [ -n "$d" ]; then
            for dep in ${d[@]}; do
                if [ ! -f $inf/$dep ]; then
                    dlst+=($dep)
                fi
            done
            if [ "${#dlst[@]}" -ge "1" ]; then
                deps+=(${dlst[@]}); dlst=
            fi
        fi

        if [ -n "$m" ]; then
            for dep in ${m[@]}; do
                if [ ! -f $inf/$dep ]; then
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

    cat $lst/* | sort -n | uniq -d > $tmpfile
    for i in $(cat $tmpfile); do
        if [ ! -d "$i" ]; then
            if [ ! -f "$i" ]; then continue; fi
            _con=$(grep "$i" $lst/*)
            for ln in $_con; do
                echo "${ln#$lst/}"
            done
        fi
    done

    rm $tmpfile
}

Del() {
    AsRoot

    for pn in $args; do
        if [ "${pn%=*}" = "root" ]; then continue; fi

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
            echo "removing: $n ($v-$r)"
            list=$(tac $root/$lst/$n)
        else
            continue
        fi

        for l in $list; do
            if [ -L $root/$l ]; then unlink $root/$l
            elif [ -f $root/$l ]; then rm -f $root/$l
            elif [ "$l" = "/" ]; then continue
            elif [ -d $root/$l ]; then find $root/$l -type d -empty -delete
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
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [DEL] $n ($v-$r)" >> $root/$log/del
    done
}

GrpDel() {
    AsRoot

    for gn in $args; do
        if [ "${gn%=*}" = "root" ]; then continue; fi

        for _pkg in $(ls $root/$inf); do
            if [ -f $root/$inf/$_pkg ]; then
                . $root/$inf/$_pkg
            fi
 
            if [ "$g" = "$gn" ]; then plst+=($n); fi
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

        if  [[ -L "$rcs/$_pkg" && -d "$rcs/$_pkg" ]]; then
            unset n s; continue
        fi

        if [ ${#n[@]} -ge 2 ]; then
            for i in ${!n[@]}; do
                s=$(echo $(declare -f package_${n[$i]} | sed -n 's/s=\(.*\);/\1/p'))
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
    if [ -f $inf/$pn ]; then
        . $inf/$pn

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
        if [ -f $lst/$pn ]; then
            cat $lst/$pn
        else
            echo "$pn: filelist not found"
        fi
    fi
}

Own() {
    if [ -n "$pt" ]; then
        _own=$(grep "$pt" $lst/*)
        for ln in $_own; do
            if [ "$pt" = "${ln#*:}" ]; then
                echo "${ln#$lst/}"
            fi
        done
    fi
}

Upd() {
    if [ "$updrcs" = true ]; then
        if [ -d $rcs ]; then
            cd $rcs; git pull origin master; SetPrm $rcs
        else
            GetRcs
        fi
    fi

    for pn in $args; do
        if  [[ -L "$rcs/$pn" && -d "$rcs/$pn" ]]; then
            if [ -f $rcs/$pn/recipe ]; then
                . $rcs/$pn/recipe; n=$pn; v1=$v; r1=$r; v=; r=
            else
                echo "$pn: recipe file not found"
            fi
        else
            if [ -f $rcs/$pn/recipe ]; then
                . $rcs/$pn/recipe; v1=$v; r1=$r; v=; r=
            else
                echo "$pn: recipe file not found"
            fi
        fi

        if [ -f $inf/$n ]; then
            . $inf/$n; v2=$v; r2=$r; v=; r=
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

    for _pn in ${ulst[@]}; do
        . $rcs/$_pn/recipe;
        RtDeps $n; _deps_=($(echo ${deps[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
        for _dep_ in ${_deps_[@]}; do
            if [ ! -f "$root/$inf/$_dep_" ]; then _mdeps_+=($_dep_); fi
        done
    done

    _mdeps_=($(echo ${_mdeps_[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '))
    args=${_mdeps_[@]}; Add

    plst=(${ulst[@]}); GetPkg

    for _pkg in ${ulst[@]}; do
        . $inf/$_pkg; _v=$v; _r=$r
        . $rcs/$_pkg/recipe
        if  [[ -L "$rcs/$_pkg" && -d "$rcs/$_pkg" ]]; then n=$_pkg; fi

        echo "updating: $n ($_v-$_r -> $v-$r)"

        if [ -f "$sys/$n" ]; then . $sys/$n
            if type upd_ >/dev/null 2>&1; then upd_; fi
        fi

        rn=$lst/$n; cp $rn $rn.bak

        backup
        tar -C $root -xpf $arc/$n-$v-$r.$pkgext
        chmod 777 $root/pkg &>/dev/null
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
            elif [ -d $l ]; then find $l -type d -empty -delete
            fi
        done

        rm $rn.bak $tmpfile

        if [ -f "$sys/$n" ]; then . $sys/$n
            if type _upd >/dev/null 2>&1; then _upd; fi
        fi

        if [ ! -d $root/$log ]; then mkdir -p $root/$log; fi
        echo "[$(date +%Y-%m-%d) $(date +%H:%M)] [UPD] $n ($v-$r)" >> $log/upd
    done
}

GrpUpd() {
    if [ -d $rcs ]; then
        cd $rcs; git pull origin master; SetPrm $rcs
    else
        GetRcs
    fi

    if [ -n "$args" ]; then
        for gn in ${args[@]}; do PkgLst; done
        GrpDep; reducedeps; _ulst=(${deps[@]})
    else
        for _pkg in $(ls $rcs); do
            if [ -f $rcs/$_pkg/recipe ]; then
               . $rcs/$_pkg/recipe
            fi
            if [ ${#n[@]} -ge 2 ]; then
                for i in ${!n[@]}; do
                    plst+=(${n[$i]})
                done
            else
                plst+=($n)
            fi
        done
        unset _pkg
        _ulst=($(for i in ${plst[@]}; do echo $i; done | sort -u))
    fi

    if [ -n "$skipupd" ]; then
        plst=(); _plst=(); deps=()
        for gn in ${skipupd[@]}; do PkgLst; done
        GrpDep; slst=(${plst[@]}); reduceupds; _ulst=(${__slst[@]})
    fi

    plst=(); _plst=(); deps=()
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
            echo "  root=<directory>                change root directory"
            echo "  skipdep                         skip dependency resolution"
            exit 1;;
        reinstall) reinst=true;;
        root=*)
            root=${i#*=};;
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