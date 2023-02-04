#!/bin/bash

set -e
set -x

ESPMB=256
DISKMB=2048

# EXPECTS:
#   final fs contents to be in /mkimage

dd if=/dev/zero of=/mkimage.img bs=1M count=$DISKMB conv=sparse
parted -s /mkimage.img -a min -- mklabel gpt unit s mkpart ESP fat32 34s 256MiB mkpart linux ext4 256MiB -35s print
cp /mkimage.img /mkimage.parts.img
PARTED_INFO="$(parted -s /mkimage.img -m -- unit s print | sed -E -e 's/([0-9])s:/\1:/g' )"
SECTOR_SIZE="$(echo "$PARTED_INFO" | sed -e '2 ! d' | cut -d: -f4)"
IFS=: read EFS_PART EFS_START EFS_END EFS_LENGTH EFS_FSTYPE EFS_LABEL EFS_FLAGS < <(echo "$PARTED_INFO" | sed -e '3 ! d')
IFS=: read TOS_PART TOS_START TOS_END TOS_LENGTH TOS_FSTYPE TOS_LABEL TOS_FLAGS < <(echo "$PARTED_INFO" | sed -e '4 ! d')

: creating intermediate images
# this is because all the offset and length stuff is inconsistently reliable.
# instead, we can do it this way and simply support everything at the cost of
# expanded tmp space requirements and extra writes to disk.  tmpfs can help.

dd if=/dev/zero of=/mkimage.efs.img bs=512 count=$EFS_LENGTH conv=sparse
mkfs.fat -S "$SECTOR_SIZE" -F 16 -n ESP /mkimage.efs.img

mmd -i /mkimage.efs.img ::/EFI
mmd -i /mkimage.efs.img ::/EFI/BOOT
mcopy -i /mkimage.efs.img /usr/lib/grub/x86_64-efi/monolithic/grubx64.efi ::/EFI/BOOT/BOOTX64.EFI

#INITRD=""
#KERNEL=""
#for f in /mkimage/boot/initrd*;do
#    INITRD="${f##/*}"
#    mcopy -i /mkimage.efs.img "$f" ::/"${f##*/}"
#done
#
#for f in /mkimage/boot/vmlinuz*;do
#    KERNEL="${f##/*}"
#    mcopy -i /mkimage.efs.img "$f" ::/"${f##*/}"
#done

mcopy -i /mkimage.efs.img - ::/EFI/BOOT/grub.cfg << EOF
set timeout=0
menuentry 'Linux' {
    set root=(hd0,gpt2)
    search.fs_label linux root
    linux /vmlinuz root=LABEL=linux noresume
    initrd /initrd.img
}
EOF

ls -l /mkimage.efs.img
dd if=/mkimage.efs.img of=/mkimage.img bs=512 seek=$EFS_START conv=notrunc,sparse

dd if=/dev/zero of=/mkimage.tos.img bs=512 count=$TOS_LENGTH conv=sparse
mkfs.ext4 -L linux -F -d /mkimage /mkimage.tos.img
ls -l /mkimage.tos.img
dd if=/mkimage.tos.img of=/mkimage.img bs=512 seek=$TOS_START conv=notrunc,sparse

parted -s /mkimage.img unit s print
parted -s /mkimage.img unit MiB print

qemu-img convert -f raw -O vhdx /mkimage.img /mkimage.vhdx
ls -l /mkimage.*
rm /mkimage.tos.img
rm /mkimage.parts.img
rm /mkimage.efs.img
rm /mkimage.img
#PARTDEV="$(losetup -f /mkimage.img --show)"
#kpartx -a "$PARTDEV"
#mkdir -p /target/boot /target/root
#mount "/dev/mapper/${PARTDEV#/dev/}"p1 /target/boot || true
#mount "/dev/mapper/${PARTDEV#/dev/}"p2 /target/root || true
#umount /target/boot || true
#umount /target/root || true
#kpartx -d "$PARTDEV"
#losetup -d "$PARTDEV"
