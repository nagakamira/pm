#!/bin/bash -e

# Copyright 2015 Ali Caliskan <ali.h.caliskan at gmail.com>
# Imgmgr is licenced under the GPLv3: http://gplv3.fsf.org

CfgKrn() {
    dracut -f -L 3 /boot/initramfs $kver
}

CfgMnt() {
    mount -o bind /etc/resolv.conf $root/etc/resolv.conf
    mount -o bind /dev $root/dev
    mount -o bind /dev/pts $root/dev/pts
    mount -o bind /proc $root/proc
    mount -o bind /run $root/run
    mount -o bind /sys $root/sys
}

CfgUsr() {
    if getent passwd $user >/dev/null; then
        userdel -r $user 2>/dev/null
    fi
    useradd -m -G users,audio,video,wheel $user
}

for i in $@; do
    case "$i" in
        -h|--help)
            echo "usage: `basename $0` [operation] <parameter>"
            echo "operation:"
            echo "  krn <kver>         create initramfs"
            echo "  mnt <root>         mount bind chroot"
            echo "  usr <user>         create an user"
            exit 0;;
        kver=*)
            kver=${i#*=};;
        root=*)
            root=${i#*=};;
        user=*)
            user=${i#*=};;
    esac
done

if [ -z "$1" ]; then $0 -h; exit 0; else o=$1; fi; name=$2

case "$o" in
    krn) CfgKrn; exit 0;;
    mnt) CfgMnt; exit 0;;
    usr) CfgUsr; exit 0;;
esac