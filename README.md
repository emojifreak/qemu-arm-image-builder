# qemu-arm-image-builder
Shell scripts to build Linux images for QEMU ARM emulator

The scripts create an image file of Debian or Devuan Linux. Their releases, such as Buster, Bullseye, Beowulf, or Chimaera can be chosen. Target architectures are arm64, armhf, and armel. Host computer should run Debian, Devuan or Ubuntu. Host architecture can be anything. To use the scripts,

1. Download all the shell script.
2. Customize shell variables in `build-arm-debian-qemu-image.sh` or `build-arm-devuan-qemu-image.sh`.
3. Run the editted shell script.
4. At the end of shell script, it prints suitable command lines to start the built image by qemu.

To have a reasonable speed of emulation, KVM has to be enabled, if possible. The scripts print suitable command options to enable KVM. Note that Intel and AMD host CPU do not have ARM KVM. Recent ARM CPUs and Linux kernels have KVM capability. I tested the scripts on Debian Bullseye arm64 with Linux kernel 5.9 and qemu 5.1. It may be impossible to build an image of Debian stretch or older, and Devuan ASCII or older.

`virt-manager` is a friendly user interface to `qemu-system-aarch64` and `qemu-system-arm`. After installing it by `apt-get --install-recommends install virt-manager`, you need to apply a patch at  https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=973680
