#!/bin/bash

# This script can be run by non-root except "nice --20" below.

wget -c -O /tmp/Maintainers.txt http://deb.devuan.org/devuan/indices/Maintainers
for p in `awk '{print $1; }' </tmp/Maintainers.txt | sed 's/:amd64$//'`; do
    if apt-cache showsrc $p | grep -q '^Testsuite:'; then
	apt-cache showsrc $p
    fi
done |
    grep ^Package: |
    sed 's/^Package: //' |
    sort |
    uniq >/tmp/pkglist-devuan.txt

if [ ! -r /var/tmp/autopkgtest-ceres-amd64.qcow2 ]; then
    echo "Make autopkgtest-ceres-amd64.qcow2 by https://github.com/emojifreak/qemu-arm-image-builder."
    echo "Also install autopkgtest and qemu-system-x86 from chimaera/ceres."
    echo "Note that /usr/bin/autopkgtest-build-qemu doesn't work at all for Devuan."
    exit 1
fi

#unset http_proxy
#unset https_proxy
set -x
#rm -rf /var/tmp/log18
mkdir /var/tmp/log18
for p in `cat /tmp/pkglist-devuan.txt`; do
  for a in amd64 ; do
    logdir=/var/tmp/log18/${p}-${a}-$EPOCHSECONDS
    count=5
    nice --20 /usr/bin/autopkgtest --timeout-factor=3 -U -B -u debci -o $logdir ${p} -- qemu --efi --timeout-reboot=180 --ram-size=3072 -c 2 /var/tmp/autopkgtest-ceres-${a}.qcow2
    while [ $count -gt 0 ] && ( fgrep -H "testbed failure" $logdir/summary || fgrep -H '<VirtSubproc>'  $logdir/log ); do
      logdir=/var/tmp/log18/${p}-${a}-$EPOCHSECONDS
      nice --20 /usr/bin/autopkgtest --timeout-factor=10 -U -B -u debci -o $logdir ${p} -- qemu -d --show-boot --efi --timeout-reboot=180 --ram-size=3072 -c 2 /var/tmp/autopkgtest-ceres-${a}.qcow2
      count=`expr $count - 1`
    done
  done
done
