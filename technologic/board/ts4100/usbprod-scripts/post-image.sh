#!/bin/bash -e

TEMPDIR=$(mktemp -d)
mkdir "${TEMPDIR}"/boot/
cp output/images/{*.dtb,zImage,rootfs.cpio.gz} "${TEMPDIR}"/boot/
cp ../technologic/board/ts4100/usbprod-scripts/tsinit.source "${TEMPDIR}"

echo "Generating U-Boot scripts"
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.scr
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.ub

cp ../technologic/board/ts4100/usbprod-scripts/blast.sh "${TEMPDIR}/blast.sh"
tar cjf output/images/ts4100-usb-production-rootfs.tar.bz2 -C "${TEMPDIR}" .

rm -r "$TEMPDIR"
