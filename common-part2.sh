cat >>${MOUNTPT}/root/.profile <<EOF
echo "$NETCONFIG"
EOF

cp /etc/resolv.conf /etc/environment ${MOUNTPT}/etc
cat >${MOUNTPT}/etc/resolv.conf <<EOF
options edns0 rotate
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF


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
  elif [ -r /usr/share/OVMF/OVMF_VARS_4M.fd ]; then
    OVMFCODE=/usr/share/OVMF/OVMF_CODE_4M.fd
    OVMFDATA=/usr/share/OVMF/OVMF_VARS_4M.fd
  else
    OVMFCODE=/usr/share/OVMF/OVMF_CODE.fd
    OVMFDATA=/usr/share/OVMF/OVMF_VARS.fd
  fi    
elif [ $ARCH = i386 ]; then 
  echo "Warning: UEFI roms for i386 is not yet available in Debian."
  OVMFCODE=/usr/share/OVMF/OVMF32_CODE_4M.secboot.fd
  OVMFDATA=/usr/share/OVMF/OVMF32_VARS_4M.fd
elif [ $ARCH = ppc64el -o $ARCH = ppc64 -o $ARCH = powerpc ]; then 
  echo "UEFI roms are unnecessary."
else
  echo "Unknown architecture and I don't know a suitable UEFI rom..."
fi

if [ $ARCH = arm64 -o  $ARCH = armhf -o  $ARCH = armel ]; then
  GRAPHICS=""
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

if [ $ARCH != ppc64el -a $ARCH != ppc64 -a $ARCH != powerpc ]; then
  cat <<EOF


To start the guest run the following commands:
cp $OVMFDATA $COPY_EFIVARS
$QEMU $KVM $GRAPHICS -net nic,model=virtio -net user -object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0,id=rng-device0 -drive if=virtio,file=${IMGFILE},index=0,format=raw,discard=unmap,detect-zeroes=unmap -drive if=pflash,format=raw,unit=0,file=${OVMFCODE},readonly=on  -drive if=pflash,format=raw,unit=1,file=$COPY_EFIVARS -m 1024 -cpu $CPU -machine $MACHINE
EOF
else
    GRAPHICS=""
    if [ $ARCH = ppc64el ]; then
	QEMUARCH=ppc64le
    elif [ $ARCH = powerpc ]; then
	QEMUARCH=ppc
    else
	QEMUARCH=$ARCH
    fi
    cat <<EOF


To start the guest run the following commands:
qemu-system-$QEMUARCH $GRAPHICS -net nic,model=virtio -net user -object rng-random,filename=/dev/urandom,id=rng0 -device virtio-rng-pci,rng=rng0,id=rng-device0 -drive if=virtio,file=${IMGFILE},index=0,format=raw,discard=unmap,detect-zeroes=unmap -m 1024
EOF
fi

