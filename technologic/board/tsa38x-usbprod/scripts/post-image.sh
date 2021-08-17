#!/bin/bash -x

TEMPDIR=$(mktemp -d)
mkdir "${TEMPDIR}"/boot/
cp output/images/{*.dtb,zImage,rootfs.cpio.gz} "${TEMPDIR}"/boot/
cp ../technologic/board/tsa38x-usbprod/scripts/boot.source "${TEMPDIR}"/boot/boot.source

echo "Generating U-Boot scripts"
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/boot/boot.source "${TEMPDIR}"/boot/boot.scr

DATESTAMP="$(date +%Y%m%d)"

cp ../technologic/board/tsa38x-usbprod/scripts/blast.sh "${TEMPDIR}/blast.sh"
tar cJf "output/images/tsa38x-usb-production-rootfs-${DATESTAMP}.tar.xz" -C "${TEMPDIR}" .

rm -r "$TEMPDIR"
