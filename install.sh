#!/bin/bash

install -v -Dm755 add.sh /usr/bin/add
install -v -Dm755 bld.sh /usr/bin/bld
install -v -Dm755 del.sh /usr/bin/del
install -v -Dm755 upd.sh /usr/bin/upd
install -v -Dm755 pkgmgr.sh /usr/bin/pkgmgr
install -v -Dm644 bld.conf /etc/bld.conf
install -v -Dm644 pkgmgr.conf /etc/pkgmgr.conf