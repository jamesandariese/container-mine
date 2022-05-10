#!/bin/bash -

set -e

guestfish[0]="guestfish"
guestfish[1]="--listen"
guestfish[2]="-x"
guestfish[3]="-w"

GUESTFISH_PID=
eval $("${guestfish[@]}")
if [ -z "$GUESTFISH_PID" ]; then
    echo "error: guestfish didn't start up, see error messages above"
    exit 1
fi

cleanup_guestfish ()
{
    guestfish --remote -- exit >/dev/null 2>&1 ||:
}
trap cleanup_guestfish EXIT ERR

guestfish -x --remote -- disk-create wip.qcow2 qcow2 80G preallocation:off
guestfish -x --remote -- add-drive wip.qcow2
guestfish -x --remote -- run
guestfish -x --remote -- part-init /dev/sda mbr
guestfish -x --remote -- part-add /dev/sda p 1 -1
guestfish -x --remote -- part-set-bootable /dev/sda 1 true
guestfish -x --remote -- mkfs-btrfs /dev/sda1
guestfish -x --remote -- mount /dev/sda1 /
guestfish -x --remote -- tar-in wip.tar /
guestfish -x --remote -- extlinux /boot
guestfish -x --remote -- ln-sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
VMLINUZ="/$(tar tf wip.tar | grep -E '(^|/)vmlinuz$' | head -1)"
INITRD="/$( tar tf wip.tar | grep -E '(^|/)initrd[.]img$' | head -1)"

printf \
'DEFAULT linux
  SAY booting linux...
LABEL linux
  KERNEL %q
  APPEND ro root=/dev/sda1 initrd=%q
' "$VMLINUZ" "$INITRD" > /tmp/syslinux.cfg

guestfish -x --remote -- upload /tmp/syslinux.cfg /boot/syslinux.cfg
