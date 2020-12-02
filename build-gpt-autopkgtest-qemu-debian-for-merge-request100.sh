#!/bin/sh

SUITE=sid # buster or bullseye or sid
ARCH=amd64 # ppc64el, ppc64, powerpc, arm64, armhf, armel, amd64, or i386

if [ $ARCH = i386 -o $ARCH = amd64 ]; then
  FIRST_TTY=ttyS0
  SECOND_TTY=ttyS1
elif  [ $ARCH = arm64 -o $ARCH = armhf -o $ARCH = armel ]; then
  FIRST_TTY=ttyAMA0
  SECOND_TTY=hvc0
elif  [ $ARCH = ppc64el -o $ARCH = ppc ]; then
  FIRST_TTY=hvc0
  SECOND_TTY=hvc1
else
  echo "Unknown architecture for selecting VM's tty..."
  exit 1
fi

IMGFILE=/var/tmp/autopkgtest-${SUITE}-${ARCH}.img
GIGABYTES=25 # total size in GB
SWAPGB=0 # swap size in GB
ROOTFS=ext4 # btrfs or ext4
MMVARIANT=important # apt, required, important, or standard
YOURHOSTNAME=host
KERNEL_CMDLINE="net.ifnames=0 consoleblank=0 rw console=$FIRST_TTY"
GRUB_TIMEOUT=0
MIRROR=http://deb.debian.org/debian/

INITUDEVPKG=systemd-sysv,udev,libpam-systemd,libnss-systemd,dbus-user-session
NETWORK=systemd-networkd # systemd-networkd or ifupdown, network-manager, none
KEYRINGPKG=debian-keyring,debian-archive-keyring,rng-tools5,openssh-server,eatmydata,gpg,dpkg-dev,python3-minimal,apparmor-utils
# You can added apparmor-utils,selinux-utils to KEYRINGPKG

# For sysvinit as /sbin/init in Debian, use the following
# MMCARIANT must be required or apt
#INITUDEVPKG=sysvinit-core,udev,libpam-elogind,lsb-base,lsb-release
#NETWORK=ifupdown

#For Devuan, use the following
#MIRROR=http://deb.devuan.org/merged/
#SUITE=ceres # ceres, chimaera or beowulf
#KEYRINGPKG=devuan-keyring,debian-keyring,rng-tools5,openssh-server,eatmydata,gpg,dpkg-dev,python3-minimal
#INITUDEVPKG=sysvinit-core,eudev,libpam-elogind,lsb-base,lsb-release
#NETWORK=ifupdown


#apt-get -q -y --no-install-recommends install binfmt-support qemu-user-static qemu-efi-arm qemu-efi-aarch64 mmdebstrap qemu-system-arm

MOUNTPT=/tmp/mnt$$
LOOPDEV=`losetup -f`
if [ -z "${LOOPDEV}" -o ! -e "${LOOPDEV}" ]; then
  echo "losetup -f failed to find an unused loop device, exiting ..."
  echo "Consider rmmod -f loop; modprobe loop"
  exit 1
fi

. ./common-part.sh

chroot ${MOUNTPT} passwd --delete root
chroot ${MOUNTPT} adduser --system --disabled-password --shell /bin/sh --home /home/debci debci
chroot ${MOUNTPT} useradd --create-home --home-dir /home/user --uid 1000 user
chroot ${MOUNTPT} passwd --delete user
cat ${MOUNTPT}/etc/passwd

if [ $ARCH != ppc64 -a $ARCH != powerpc ]; then
  cat << EOF >${MOUNTPT}/etc/apt/sources.list
deb $MIRROR $SUITE main contrib non-free
deb-src $MIRROR $SUITE main contrib non-free
EOF
else
  cat << EOF >${MOUNTPT}/etc/apt/sources.list
deb http://deb.debian.org/debian-ports/ sid main
deb-src http://deb.debian.org/debian/ sid main
deb http://deb.debian.org/debian-ports/ unreleased main
deb-src http://deb.debian.org/debian-ports/ unreleased main
EOF
fi

echo "Acquire::Languages \"none\";" > ${MOUNTPT}/etc/apt/apt.conf.d/90nolanguages
echo 'force-unsafe-io' > ${MOUNTPT}/etc/dpkg/dpkg.cfg.d/autopkgtest
cp /dev/null ${MOUNTPT}/etc/environment
cat >${MOUNTPT}/etc/resolv.conf <<EOF
options edns0 rotate
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
echo 'APT::Periodic::Enable 0;' > ${MOUNTPT}/etc/apt/apt.conf.d/02periodic

if echo "$INITUDEVPKG" | grep -q systemd; then
  cat <<EOF > "${MOUNTPT}/etc/systemd/system/autopkgtest.service"
[Unit]
Description=autopkgtest root shell on $SECOND_TTY
ConditionPathExists=/dev/$SECOND_TTY

[Service]
ExecStart=/bin/sh
StandardInput=tty-fail
StandardOutput=tty
StandardError=tty
TTYPath=/dev/$SECOND_TTY
SendSIGHUP=yes
# ignore I/O errors on unusable $SECOND_TTY
SuccessExitStatus=0 208 SIGHUP SIGINT SIGTERM SIGPIPE

[Install]
WantedBy=multi-user.target
EOF
  chroot ${MOUNTPT} systemctl enable autopkgtest.service
  chroot ${MOUNTPT} systemctl enable serial-getty@${FIRST_TTY}
elif echo "$INITUDEVPKG" | grep -q sysvinit-core; then
  cat >>${MOUNTPT}/etc/inittab <<EOF
S0:2345:respawn:/sbin/agetty -8 --noissue $FIRST_TTY 115200 vt100
EOF
  cat <<EOF > "${MOUNTPT}/etc/init.d/autopkgtest"
#!/bin/sh
### BEGIN INIT INFO
# Provides:          autopkgtest
# Required-Start:    \$all
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:
### END INIT INFO

if [ "\$1" = start ]; then
    echo "Starting root shell on $SECOND_TTY for autopkgtest"
    (setsid sh </dev/$SECOND_TTY >/dev/$SECOND_TTY 2>&1) &
fi
EOF
  chmod 755 "${MOUNTPT}/etc/init.d/autopkgtest"
  chroot "${MOUNTPT}" update-rc.d autopkgtest defaults
else
  echo "Unknwon /sbin/init. Please update this script by yourself."
  exit 1
fi 

echo '127.0.1.1  host' >> ${MOUNTPT}/etc/hosts
chroot ${MOUNTPT} apt-get -q -y --autoremove purge cron anacron
chroot ${MOUNTPT} apt-get -q clean
chroot ${MOUNTPT} apt-get -q update

if [ $ROOTFS = ext4 ]; then
  e4defrag ${MOUNTPT}  >/dev/null
elif [ $ROOTFS = btrfs ]; then
  btrfs filesystem defragment -r ${MOUNTPT}
fi
fstrim ${MOUNTPT}/boot/efi
fstrim ${MOUNTPT}
  
if [ $ARCH != ppc64el -a $ARCH != ppc64 ]; then
  umount -f ${MOUNTPT}/boot/efi
fi
umount -f ${MOUNTPT}
rm -rf ${MOUNTPT}
if [ $ROOTFS = ext4 ]; then
  tune2fs -e panic -o journal_data_writeback,nobarrier,discard ${LOOPDEV}p2
fi
losetup -d ${LOOPDEV}
set -x
rm -f "/var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2"
qemu-img convert -p -O qcow2 -t unsafe -c -o compat=1.1 -o lazy_refcounts=on -o preallocation=off $IMGFILE  "/var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2"
rm -f $IMGFILE
set +x

if [ $ARCH = amd64 ]; then
  cat <<EOF
You have to install ovmf and qemu-system-x86. Start the testbed as
autopkgtest -B -u debci dpkg -- qemu --efi -q qemu-system-x86_64 --qemu-options "-machine q35" /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
elif  [ $ARCH = i386 ]; then
  cat <<EOF
You need UEFI roms (OVMF) for i386, which is not included in Debian's ovmf. With it, use
autopkgtest -B -u debci dpkg -- qemu --efi -q qemu-system-i386 --qemu-options "-machine q35" /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
elif  [ $ARCH = arm64 ]; then
  cat <<EOF
You may have to mannually apply the patch to autopkgtest-virt-qemu at 
https://salsa.debian.org/ci-team/autopkgtest/-/merge_requests/97

After that, use
autopkgtest -u debci -B dpkg -- qemu --efi  -q qemu-system-aarch64 --qemu-options "-machine virt -cpu max" --timeout-reboot 300 /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
elif  [ $ARCH = armhf -o $ARCH = armel ]; then
  cat <<EOF
You may have to mannually apply the patch to autopkgtest-virt-qemu at 
https://salsa.debian.org/ci-team/autopkgtest/-/merge_requests/97

After that, use
autopkgtest -u debci -B dpkg -- qemu --efi  -q qemu-system-arm "-machine virt -cpu max" --timeout-reboot 300 /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
elif [ $ARCH = ppc64el  ]; then
  cat <<EOF
You may have to mannually apply the patch to autopkgtest-virt-qemu at 
https://salsa.debian.org/ci-team/autopkgtest/-/merge_requests/97

After that, use
autopkgtest -B -u debci bash -- qemu -q qemu-system-ppc64le --timeout-reboot 300 /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
elif [ $ARCH = ppc64  ]; then
  cat <<EOF
You may have to mannually apply the patch to autopkgtest-virt-qemu at 
https://salsa.debian.org/ci-team/autopkgtest/-/merge_requests/97

After that, use
autopkgtest -B -u debci bash -- qemu --vm-arch ppc64 -q qemu-system-ppc64 --timeout-reboot 300 /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
elif [ $ARCH = powerpc  ]; then
  cat <<EOF
You may have to mannually apply the patch to autopkgtest-virt-qemu at 
https://salsa.debian.org/ci-team/autopkgtest/-/merge_requests/100

After that, use
autopkgtest -B -u debci bash -- qemu --vm-arch powerpc -q qemu-system-ppc --timeout-reboot 300 /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
else
  echo "Currently unknown architecture..."
fi
exit 0
