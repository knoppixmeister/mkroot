#!/bin/echo Use as an argument to mkroot.sh

download f3a20cbd8c140acbbba76eb6ca1f56a8812c321f \
  https://kernel.org/pub/linux/kernel/v4.x/linux-4.10.tar.gz

[ -z "$TARGET" ] && TARGET="${CROSS_BASE/-*/}"

# Add generic info to arch-specific part of miniconfig
getminiconfig()
{
  echo "$KERNEL_CONFIG"
  echo "
# CONFIG_EMBEDDED is not set
CONFIG_EARLY_PRINTK=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
CONFIG_BINFMT_ELF=y
CONFIG_BINFMT_SCRIPT=y
CONFIG_MISC_FILESYSTEMS=y
CONFIG_DEVTMPFS=y
"
}

# Target-specific info in an if/else staircase

if [ "$TARGET" == aarch64 ]
then
  QEMU="qemu-system-aarch64 -M virt -cpu cortex-a57"
  KARCH=arm64
  KARGS="console=ttyAMA0"
  VMLINUX=arch/arm64/boot/Image
  KERNEL_CONFIG="
CONFIG_SERIAL_OF_PLATFORM=y
CONFIG_SERIAL_AMBA_PL011=y
CONFIG_SERIAL_AMBA_PL011_CONSOLE=y
CONFIG_RTC_CLASS=y
CONFIG_RTC_HCTOSYS=y
CONFIG_RTC_DRV_PL031=y
"
elif [ "$TARGET" == armv5l ]
then
  QEMU="qemu-system-arm -M versatilepb -net nic,model=rtl8139 -net user"
  KARCH=arm
  KARGS="console=ttyAMA0"
  VMLINUX=arch/arm/boot/zImage
  KERNEL_CONFIG="
CONFIG_CPU_ARM926T=y
CONFIG_MMU=y
CONFIG_VFP=y
CONFIG_ARM_THUMB=y
CONFIG_AEABI=y

CONFIG_ARCH_VERSATILE=y
#CONFIG_PCI_LEGACY=y
#CONFIG_SERIAL_NONSTANDARD=y
CONFIG_SERIAL_AMBA_PL011=y
CONFIG_SERIAL_AMBA_PL011_CONSOLE=y
#CONFIG_RTC_CLASS=y
#CONFIG_RTC_DRV_PL031=y
#CONFIG_SCSI_SYM53C8XX_2=y
#CONFIG_SCSI_SYM53C8XX_DMA_ADDRESSING_MODE=0
#CONFIG_SCSI_SYM53C8XX_MMIO=y

# The switch to device-tree-only added this mess
CONFIG_ATAGS=y
CONFIG_DEPRECATED_PARAM_STRUCT=y
CONFIG_ARM_APPENDED_DTB=y
CONFIG_ARM_ATAG_DTB_COMPAT=y
CONFIG_ARM_ATAG_DTB_COMPAT_CMDLINE_EXTEND=y
"
  RUN_AFTER="cat arch/arm/boot/dts/versatile-pb.dtb >> $VMLINUX"
elif [ "$TARGET" == powerpc ]
then
  QEMU="qemu-system-ppc -M g3beige"
  KARCH=powerpc
  KARGS="console=ttyS0"
  VMLINUX=vmlinux
  KERNEL_CONFIG="
CONFIG_ALTIVEC=y
CONFIG_PPC_PMAC=y
CONFIG_PPC_OF_BOOT_TRAMPOLINE=y
CONFIG_PPC601_SYNC_FIX=y
CONFIG_BLK_DEV_IDE_PMAC=y
CONFIG_BLK_DEV_IDE_PMAC_ATA100FIRST=y
CONFIG_MACINTOSH_DRIVERS=y
CONFIG_ADB=y
CONFIG_ADB_CUDA=y
CONFIG_NE2K_PCI=y
CONFIG_SERIO=y
CONFIG_SERIAL_PMACZILOG=y
CONFIG_SERIAL_PMACZILOG_TTYS=y
CONFIG_SERIAL_PMACZILOG_CONSOLE=y
CONFIG_BOOTX_TEXT=y
"
elif [ "$TARGET" == sh4 ]
then
  QEMU="qemu-system-sh4 -M r2d -monitor null -serial null -serial stdio"
  KARCH=sh
  KARGS="console=ttySC1 noiotrap"
  VMLINUX=arch/sh/boot/zImage
  KERNEL_CONFIG="
CONFIG_CPU_SUBTYPE_SH7751R=y
CONFIG_MMU=y
CONFIG_MEMORY_START=0x0c000000
CONFIG_VSYSCALL=y
CONFIG_SH_FPU=y
CONFIG_SH_RTS7751R2D=y
CONFIG_RTS7751R2D_PLUS=y
CONFIG_SERIAL_SH_SCI=y
CONFIG_SERIAL_SH_SCI_CONSOLE=y
"
elif [ "$TARGET" == x86_64 ]
then
  QEMU=qemu-system-x86_64
  KARCH=x86
  KARGS="console=ttyS0"
  VMLINUX=arch/x86/boot/bzImage
  KERNEL_CONFIG="
CONFIG_64BIT=y
CONFIG_ACPI=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
"
else
  echo "Unknown \$TARGET"
  exit 1
fi

# Build kernel

setupfor linux
make ARCH=$KARCH allnoconfig KCONFIG_ALLCONFIG=<(getminiconfig) &&
make ARCH=$KARCH CROSS_COMPILE="$CROSS_COMPILE" -j $(nproc) || exit 1

if [ ! -z "$RUN_AFTER" ]
then
  eval "$RUN_AFTER" || exit 1
fi

cp "$VMLINUX" "$OUTPUT/$(basename "$VMLINUX")" &&
echo "$QEMU -nographic -no-reboot -m 256" \
     "-append \"panic=1 HOST=$TARGET $KARGS\"" \
     "-kernel $(basename "$VMLINUX") -initrd ${CROSS_BASE}root.cpio.gz" \
     > "$OUTPUT/qemu-$TARGET.sh" &&
chmod +x "$OUTPUT/qemu-$TARGET.sh"
cleanup

