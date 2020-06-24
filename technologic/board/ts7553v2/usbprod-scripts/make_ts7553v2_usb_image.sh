#!/bin/bash -e

TEMPDIR=$(mktemp -d)
mkdir "${TEMPDIR}"/boot/
cp output/images/{*.dtb,zImage,rootfs.cpio.gz} "${TEMPDIR}"/boot/
cp ../technologic/board/ts7553v2/usbprod-scripts/{tsinit.ub,tsinit.source} "${TEMPDIR}"
cp ../technologic/board/ts7553v2/usbprod-scripts/blast.sh "${TEMPDIR}/blast.sh"
tar cjf output/images/ts7553v2-usb-production-rootfs.tar.bz2 -C "${TEMPDIR}" .
rm -r "$TEMPDIR"
