#!/bin/sh

SUITE=sid # buster or bullseye or sid
ARCH=ppc64el # ppc64el or arm64 or armhf or armel or amd64 or i386
IMGFILE=/var/tmp/autopkgtest-${SUITE}-${ARCH}.img
GIGABYTES=25 # total size in GB
SWAPGB=0 # swap size in GB
ROOTFS=ext4 # btrfs or ext4
MMVARIANT=apt # apt, required, important, or standard
YOURHOSTNAME=host
KERNEL_CMDLINE='net.ifnames=0 consoleblank=0 rw console=ttyS0 systemd.unified_cgroup_hierarchy=1'
GRUB_TIMEOUT=0
MIRROR=http://deb.debian.org/debian/

INITUDEVPKG=systemd-sysv,udev,libpam-systemd,libnss-systemd,dbus-user-session
NETWORK=systemd-networkd # systemd-networkd or ifupdown, network-manager, none
KEYRINGPKG=debian-archive-keyring,openssh-server,eatmydata,gpg,dpkg-dev,python3-minimal
# You can added apparmor-utils,selinux-utils to KEYRINGPKG

# For sysvinit as /sbin/init in Debian, use the following
#INITUDEVPKG=sysvinit-core,udev,libpam-elogind,lsb-base,lsb-release
#NETWORK=ifupdown

#For Devuan, use the following
#MIRROR=http://deb.devuan.org/merged/
#SUITE=ceres # ceres, chimaera or beowulf
#KEYRINGPKG=devuan-keyring,openssh-server,eatmydata,gpg,dpkg-dev,python3-minimal
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

cat << EOF >${MOUNTPT}/etc/apt/sources.list
deb $MIRROR $SUITE main contrib non-free
deb-src $MIRROR $SUITE main contrib non-free
EOF
echo "Acquire::Languages \"none\";" > ${MOUNTPT}/etc/apt/apt.conf.d/90nolanguages
echo 'force-unsafe-io' > ${MOUNTPT}/etc/dpkg/dpkg.cfg.d/autopkgtest
cp /dev/null ${MOUNTPT}/etc/environment
echo 'APT::Periodic::Enable 0;' > ${MOUNTPT}/etc/apt/apt.conf.d/02periodic

if echo "$INITUDEVPKG" | grep -q systemd; then
  cat <<EOF > "${MOUNTPT}/etc/systemd/system/autopkgtest.service"
[Unit]
Description=autopkgtest root shell on ttyS1
ConditionPathExists=/dev/ttyS1

[Service]
ExecStart=/bin/sh
StandardInput=tty-fail
StandardOutput=tty
StandardError=tty
TTYPath=/dev/ttyS1
SendSIGHUP=yes
# ignore I/O errors on unusable ttyS1
SuccessExitStatus=0 208 SIGHUP SIGINT SIGTERM SIGPIPE

[Install]
WantedBy=multi-user.target
EOF
  chroot ${MOUNTPT} systemctl enable autopkgtest.service
  chroot ${MOUNTPT} systemctl enable serial-getty@ttyS0
elif echo "$INITUDEVPKG" | grep -q sysvinit-core; then
  cat >>${MOUNTPT}/etc/inittab <<'EOF'
S0:2345:respawn:/sbin/agetty -8 --noissue ttyS0 115200 vt100
#S1:2345:respawn:/sbin/agetty -8 --noissue --local-line=always -a root ttyS1 115200 vt100
#S1:2345:respawn:/bin/sh -i
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
    echo "Starting root shell on ttyS1 for autopkgtest"
    (setsid sh </dev/ttyS1 >/dev/ttyS1 2>&1) &
fi
EOF
  chmod 755 "${MOUNTPT}/etc/init.d/autopkgtest"
  chroot "${MOUNTPT}" update-rc.d autopkgtest defaults
  if echo "$ARCH" | grep -q arm; then
    echo 'AMA0:2345:respawn:/sbin/agetty -8 ttyAMA0 115200 vt100' >>${MOUNTPT}/etc/inittab
  fi
else
  echo "Unknwon /sbin/init. Please update this script by yourself."
  exit 1
fi 

chroot ${MOUNTPT} apt-get clean
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
losetup -d ${LOOPDEV}
set -x
rm -f "/var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2"
qemu-img convert -p -O qcow2 -t unsafe -c -o compat=1.1 -o lazy_refcounts=on -o preallocation=off $IMGFILE  "/var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2"
rm -f $IMGFILE
set +x

if [ $ARCH = amd64 ]; then
  cat <<EOF
You have to install ovmf and qemu-system-x86. Start the testbed as
autopkgtest-5.15 -B -u debci dpkg -- qemu --efi -q qemu-system-x86_64 --qemu-options "-machine q35" /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
elif  [ $ARCH = i386 ]; then
  cat <<EOF
You need UEFI roms (OVMF) for i386, which is not included in Debian's ovmf. With it, use
autopkgtest-5.15 -B -u debci dpkg -- qemu --efi -q qemu-system-i386 --qemu-options "-machine q35" /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
elif  [ $ARCH = arm64 ]; then
  cat <<EOF
You have to mannually apply the patch to autopkgtest-virt-qemu at 
https://bugs.debian.org/cgi-bin/bugreport.cgi?att=1;bug=973038;filename=simpler-patch.txt;msg=45

After that, use
autopkgtest-5.15-patched -u debci -B dpkg -- qemu --efi  -q qemu-system-aarch64 --timeout-reboot 300 /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
elif  [ $ARCH = armhf -o $ARCH = armel ]; then
  cat <<EOF
You have to mannually apply the patch to autopkgtest-virt-qemu at 
https://bugs.debian.org/cgi-bin/bugreport.cgi?att=1;bug=973038;filename=simpler-patch.txt;msg=45

After that, use
autopkgtest-5.15-patched -u debci -B dpkg -- qemu --efi  -q qemu-system-arm --timeout-reboot 300 /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
elif [ $ARCH = ppc64el -o $ARCH = ppc64 ]; then
  cat <<EOF
You have to mannually apply the patch to autopkgtest-virt-qemu at
https://bugs.debian.org/cgi-bin/bugreport.cgi?att=1;bug=973038;filename=simpler-patch.txt;msg=45

After that, use
autopkgtest-5.15-patched -B -u debci bash -- qemu --efi -q qemu-system-ppc64le --timeout-reboot 300 /var/tmp/autopkgtest-${SUITE}-${ARCH}.qcow2
EOF
else
  echo "Currently unknown architecture..."
fi
exit 0
