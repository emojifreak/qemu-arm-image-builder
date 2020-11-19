#!/bin/sh

umount -qf ${LOOPDEV}p1
umount -qf ${LOOPDEV}p2
losetup -d ${LOOPDEV}
rm -f ${IMGFILE}
#dd if=/dev/zero of=${IMGFILE} count=1 seek=`expr ${GIGABYTES} \* 1024 \* 2048`
qemu-img create -f raw -o preallocation=off -o nocow=off ${IMGFILE} ${GIGABYTES}G
losetup -P ${LOOPDEV} ${IMGFILE}
ESP=esp
BOOTSIZE=100MiB
if [ $ARCH = ppc64 -o $ARCH = ppc64el ]; then
  BOOTSIZE=9MiB
  ESP=prep
fi
parted -- ${LOOPDEV} mklabel gpt mkpart ESP fat32 0% $BOOTSIZE mkpart ROOT ${ROOTFS} $BOOTSIZE -${SWAPGB}GiB set 1 $ESP on
if [ ${SWAPGB} -gt 0 ]; then
    parted -- ${LOOPDEV} mkpart SWAP linux-swap -${SWAPGB}GiB 100%
fi

while [ ! -b ${LOOPDEV}p2 ]; do
    partprobe ${LOOPDEV}
    sleep 1
done

if [ $ARCH != ppc64el -a $ARCH != ppc64 ]; then
  mkfs.vfat -F 32 -n ESP ${LOOPDEV}p1
else
  dd bs=65536 if=/dev/zero of=${LOOPDEV}p1
fi

eval mkfs.${ROOTFS} -L ROOT ${LOOPDEV}p2
if [ ${SWAPGB} -gt 0 ]; then
    mkswap -L SWAP ${LOOPDEV}p3
fi

mkdir -p ${MOUNTPT}
if [ ${ROOTFS} = btrfs ]; then
    mount -t ${ROOTFS} -o  ssd,async,lazytime,discard,noatime,autodefrag,nobarrier,commit=3600,compress-force=lzo ${LOOPDEV}p2 ${MOUNTPT}
elif [ ${ROOTFS} = ext4 ]; then
    mount -t ${ROOTFS} -o async,lazytime,discard,noatime,nobarrier,commit=3600,delalloc,noauto_da_alloc,data=writeback ${LOOPDEV}p2 ${MOUNTPT}
else
    echo "Unsupported filesystem type ${ROOTFS}"
    exit 1
fi

if [ "${ARCH}" = arm64 ]; then
    KERNELPKG=linux-image-arm64
    GRUBPKG=grub-efi-arm64
    GRUBTARGET=arm64-efi
elif [ "${ARCH}" = armhf -o  "${ARCH}" = armel ]; then
    KERNELPKG=linux-image-armmp-lpae:armhf
    GRUBPKG=grub-efi-arm
    GRUBTARGET=arm-efi
elif [ "${ARCH}" = amd64 ]; then
    KERNELPKG=linux-image-amd64
    GRUBPKG=grub-efi-amd64
    GRUBTARGET=x86_64-efi
elif [ "${ARCH}" = i386 ]; then
    KERNELPKG=linux-image-686-pae
    GRUBPKG=grub-efi-ia32
    GRUBTARGET=i386-efi
elif [ "${ARCH}" = ppc64el ]; then
    KERNELPKG=linux-image-powerpc64le
    GRUBPKG=grub-ieee1275
    GRUBTARGET=powerpc-ieee1275
elif [ "${ARCH}" = ppc64 ]; then
    KERNELPKG=linux-image-powerpc64
    GRUBPKG=grub-ieee1275
    GRUBTARGET=powerpc-ieee1275
    apt-get -q -y install debian-ports-archive-keyring
    KEYRINGPKG=debian-ports-archive-keyring,$KEYRINGPKG
    MIRROR=-
    MMCOMPONENTS=main
#elif [ "${ARCH}" = sparc64 ]; then
#    KERNELPKG=linux-image-sparc64
#    GRUBPKG=grub-ieee1275
#    GRUBTARGET=sparc64-ieee1275
else
  echo "Unknown supported architecture ${ARCH} !"
  exit 1
fi

if [ -z "$MMCOMPONENTS" ]; then
  MMCOMPONENTS="main contrib non-free"
fi

if [ ${ARCH} = armel ]; then
    MMARCH=armel,armhf
else
    MMARCH=${ARCH}
fi

if [ $NETWORK = ifupdown ]; then
    NETPKG=ifupdown,isc-dhcp-client
elif [ $NETWORK = network-manager ]; then
    NETPKG=network-manager
elif [ $NETWORK = systemd-networkd ]; then
    NETPKG=systemd
else
    NETPKG=iproute2
fi

set -x
if [ $ARCH != ppc64 ]; then
  mmdebstrap --architectures=$MMARCH --variant=$MMVARIANT --components="$MMCOMPONENTS" --include=${KEYRINGPKG},${INITUDEVPKG},${KERNELPKG},${NETPKG},initramfs-tools,kmod,e2fsprogs,btrfs-progs,locales,tzdata,apt-utils,whiptail,debconf-i18n,keyboard-configuration,console-setup ${SUITE} ${MOUNTPT} ${MIRROR}
else
  mmdebstrap --architectures=$MMARCH --variant=$MMVARIANT --components="$MMCOMPONENTS" --include=${KEYRINGPKG},${INITUDEVPKG},${KERNELPKG},${NETPKG},initramfs-tools,kmod,e2fsprogs,btrfs-progs,locales,tzdata,apt-utils,whiptail,debconf-i18n,keyboard-configuration,console-setup ${SUITE} ${MOUNTPT} ${MIRROR} <<EOF
deb http://deb.debian.org/debian-ports sid main
deb http://deb.debian.org/debian-ports unreleased main
EOF
fi

if [ $ARCH != ppc64el -a $ARCH != ppc64 ]; then
  mkdir -p ${MOUNTPT}/boot/efi
  mount -o async,discard,lazytime,noatime ${LOOPDEV}p1 ${MOUNTPT}/boot/efi
fi


chroot ${MOUNTPT} dpkg-reconfigure locales
chroot ${MOUNTPT} dpkg-reconfigure tzdata
chroot ${MOUNTPT} dpkg-reconfigure keyboard-configuration
chroot ${MOUNTPT} passwd root
#chroot ${MOUNTPT} pam-auth-update
set +x

#touch ${MOUNTPT}${LOOPDEV}
#mount --bind ${LOOPDEV} ${MOUNTPT}${LOOPDEV}
mount --bind /dev ${MOUNTPT}/dev
mount --bind /dev/pts ${MOUNTPT}/dev/pts
mount --bind /sys ${MOUNTPT}/sys
mount --bind /proc ${MOUNTPT}/proc

chroot ${MOUNTPT} apt-get -q update
chroot ${MOUNTPT} apt-get -q -y --install-recommends --no-show-progress install ${GRUBPKG}
chroot ${MOUNTPT} apt-get -q -y --autoremove --no-show-progress purge os-prober
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*$/GRUB_CMDLINE_LINUX_DEFAULT="'"${KERNEL_CMDLINE}"\"/ ${MOUNTPT}/etc/default/grub
sed -i 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT='"${GRUB_TIMEOUT}"/ ${MOUNTPT}/etc/default/grub
#cat ${MOUNTPT}/etc/default/grub
chroot ${MOUNTPT} grub-mkconfig -o /boot/grub/grub.cfg
# --force-extra-removable is necessary below!
if [ $ARCH != ppc64el -a $ARCH != ppc64 ]; then
  chroot ${MOUNTPT} grub-install --target=${GRUBTARGET} --force-extra-removable --no-nvram --no-floppy --modules="part_msdos part_gpt" --grub-mkdevicemap=/boot/grub/device.map ${LOOPDEV}
else
  chroot ${MOUNTPT} grub-install --target=${GRUBTARGET} --no-nvram --no-floppy --modules="part_msdos part_gpt" --grub-mkdevicemap=/boot/grub/device.map ${LOOPDEV}p1
fi

umount -f ${MOUNTPT}/dev/pts
umount -f ${MOUNTPT}/dev
#umount -f ${MOUNTPT}${LOOPDEV}
#rm -f ${MOUNTPT}${LOOPDEV}
umount -f ${MOUNTPT}/sys
umount -f ${MOUNTPT}/proc

cp /etc/resolv.conf /etc/environment ${MOUNTPT}/etc
echo ${YOURHOSTNAME} >${MOUNTPT}/etc/hostname
if [ ${ROOTFS} = btrfs ]; then
   cat >${MOUNTPT}/etc/fstab <<EOF
LABEL=ROOT / ${ROOTFS} rw,ssd,async,lazytime,discard,strictatime,autodefrag,nobarrier,commit=3600,compress-force=lzo 0 1
EOF
elif [ ${ROOTFS} = ext4 ]; then
   cat >${MOUNTPT}/etc/fstab <<EOF
LABEL=ROOT / ${ROOTFS} rw,async,lazytime,discard,strictatime,nobarrier,commit=3600,data=writeback 0 1
EOF
else
    echo "Unsupported filesystem $ROOTFS"
    exit 0
fi

if [ $ARCH != ppc64el -a $ARCH != ppc64 ]; then
   cat >>${MOUNTPT}/etc/fstab <<EOF
LABEL=ESP /boot/efi vfat rw,async,lazytime,discard 0 2
EOF
fi

if [ "$SWAPGB" -gt 0 ]; then
  echo 'LABEL=SWAP none swap sw,discard 0 0' >>${MOUNTPT}/etc/fstab
fi

if [ $NETWORK != none ]; then 
  echo "IPv4 DHCP is assumed."
  NETIF=eth0

  if [ $NETWORK = ifupdown ]; then
    NETCONFIG="Network configurations can be changed by /etc/network/interfaces"
    cat >>${MOUNTPT}/etc/network/interfaces <<EOF
auto $NETIF
iface $NETIF inet dhcp
EOF
    echo "/etc/network/interfaces is"
    cat ${MOUNTPT}/etc/network/interfaces
  elif [ $NETWORK = network-manager ]; then
    NETCONFIG="Network configurations can be changed by nmtui"
  elif [ $NETWORK = systemd-networkd ]; then
    NETCONFIG="Network configurations can be changed by /etc/systemd/network/${NETIF}.network"
    cat >${MOUNTPT}/etc/systemd/network/${NETIF}.network <<EOF
[Match]
Name=${NETIF}

[Network]
DHCP=yes
EOF
    chroot ${MOUNTPT} systemctl enable systemd-networkd
  fi
fi

set -x
if [ "$SUITE" != buster -a "$SUITE" != beowulf ]; then
  chroot ${MOUNTPT} apt-get -q -y --purge --autoremove purge python2.7-minimal
fi
if [ $NETWORK = network-manager -o $NETWORK = systemd-networkd ]; then
  chroot ${MOUNTPT} apt-get -q -y --purge --autoremove purge ifupdown
  rm -f ${MOUNTPT}/etc/network/interfaces
fi  
set +x

cat >>${MOUNTPT}/root/.profile <<EOF
echo "$NETCONFIG"
EOF

if [ -w ${MOUNTPT}/etc/inittab ]; then
    echo 'C0:2345:respawn:/sbin/getty -8 --noclear --keep-baud console 115200,38400,9600' >>${MOUNTPT}/etc/inittab
fi


HOSTARCH=`dpkg --print-architecture`

# Identify the command for starting the guest
  
if [ $ARCH = arm64 ]; then
  OVMFCODE=/usr/share/AAVMF/AAVMF_CODE.fd
  OVMFDATA=/usr/share/AAVMF/AAVMF_VARS.fd
elif [ $ARCH = armhf -o $ARCH = armel ]; then 
  OVMFCODE=/usr/share/AAVMF/AAVMF32_CODE.fd
  OVMFDATA=/usr/share/AAVMF/AAVMF32_VARS.fd
elif [ $ARCH = amd64 ]; then
  # Debian ovmf packages are broken
  if [ -r /usr/local/share/OVMF-Fedora/OVMF_CODE.secboot.fd ]; then
    OVMFCODE=/usr/local/share/OVMF-Fedora/OVMF_CODE.secboot.fd
    OVMFDATA=/usr/local/share/OVMF-Fedora/OVMF_VARS.secboot.fd
  elif [ -r /usr/share/OVMF/OVMF_VARS_4M.ms.fd ]; then
    OVMFCODE=/usr/share/OVMF/OVMF_CODE_4M.fd
    OVMFDATA=/usr/share/OVMF/OVMF_VARS_4M.fd
  else
    OVMFCODE=/usr/share/OVMF/OVMF_CODE.fd
    OVMFDATA=/usr/share/OVMF/OVMF_VARS.fd
  fi    
elif [ $ARCH = i386 ]; then 
  echo "Warning: UEFI roms for i386 is not yet available in Debian."
  OVMFCODE=/usr/local/share/OVMF-Fedora/OVMF32_CODE.secboot.fd
  OVMFDATA=/usr/local/share/OVMF-Fedora/OVMF32_VARS.secboot.fd
elif [ $ARCH = ppc64el -o $ARCH = ppc64 ]; then 
  echo "UEFI roms are unnecessary."
else
  echo "Unknown architecture and I don't know a suitable UEFI rom..."
fi

if [ $ARCH = arm64 -o  $ARCH = armhf -o  $ARCH = armel ]; then
  GRAPHICS=-nographic
  MACHINE=virt
  if [ $HOSTARCH = arm64 ]; then
    QEMU=qemu-system-aarch64
    KVM='-enable-kvm'
    if [ $ARCH = arm64 ]; then
      CPU=host
    else
      CPU=host,aarch64=off
    fi
  elif [ $HOSTARCH = armhf ]; then
    if [ $ARCH = arm64 ]; then
      QEMU=qemu-system-aarch64
      CPU=max
      KVM=
    else
      QEMU=qemu-system-arm
      CPU=host
      if [ -e /dev/kvm ]; then
	KVM=-enable-kvm
      else
	KVM=
      fi
    fi
  elif [ $HOSTARCH = armel ]; then
    if [ $ARCH = arm64 ]; then
      QEMU=qemu-system-aarch64
      CPU=max
      KVM=
    elif [ $ARCH = armhf ]; then
      QEMU=qemu-system-arm
      CPU=max
      KVM=
    else
      QEMU=qemu-system-arm
      CPU=host
      KVM=
    fi
  else
    KVM=
    CPU=max
    if [ $ARCH = arm64 ]; then
      QEMU=qemu-system-aarch64
    else
      QEMU=qemu-system-arm
    fi
  fi

elif [ $ARCH = amd64 ]; then
  QEMU=qemu-system-x86_64
  GRAPHICS=
  CPU="max"
  if [ $HOSTARCH = amd64 -a  -e /dev/kvm ]; then
    KVM=-enable-kvm
    MACHINE="q35,smm=on,accel=kvm -global driver=cfi.pflash01,property=secure,value=on"
  else
    KVM=
    MACHINE="q35,smm=on -global driver=cfi.pflash01,property=secure,value=on"
  fi
elif [ $ARCH = i386 ]; then
  MACHINE="q35,smm=on -global driver=cfi.pflash01,property=secure,value=on"
  QEMU=qemu-system-i386
  GRAPHICS=
  CPU="max"
  KVM=
  if [ -e /dev/kvm ]; then
    if [ $HOSTARCH = amd64 -o  $HOSTARCH = i386 ]; then
    KVM=-enable-kvm
    MACHINE="q35,smm=on,accel=kvm -global driver=cfi.pflash01,property=secure,value=on"
    fi
  fi
fi
# For UEFI secure boot of Intel/AMD hosts, use
# -machine q35,smm=on
# -global driver=cfi.pflash01,property=secure,value=on
# as explained at https://github.com/tianocore/edk2/blob/master/OvmfPkg/README

# For UEFI secure boot of an AArch64 hosts, use -machine virt,secure=on

COPY_EFIVARS=`dirname ${IMGFILE}`/`basename ${IMGFILE}  .img`-efivars.fd

if [ $ARCH != ppc64el -a $ARCH != ppc64 ]; then
  cat <<EOF


To start the guest run the following commands:
cp $OVMFDATA $COPY_EFIVARS
$QEMU $KVM $GRAPHICS -net nic,model=virtio -net user -object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0,id=rng-device0 -drive if=virtio,file=${IMGFILE},index=0,format=raw,discard=unmap,detect-zeroes=unmap -drive if=pflash,format=raw,unit=0,file=${OVMFCODE},readonly=on  -drive if=pflash,format=raw,unit=1,file=$COPY_EFIVARS -m 1024 -cpu $CPU -machine $MACHINE
EOF
else 
  echo "Use virt-manager to start the made image."
fi
