#!/bin/bash -e

TEMPDIR=$(mktemp -d) 
cp output/images/{*.dtb,zImage,rootfs.cpio.gz} "${TEMPDIR}/"
cp ../technologic/board/ts7250v3/usbprod-scripts/{boot.scr,boot.source} "${TEMPDIR}/"
cp ../technologic/board/ts7250v3/usbprod-scripts/blast-ts7250v3.sh "${TEMPDIR}/blast.sh"
tar cjf output/images/ts7250v3-usb-production-rootfs.tar.bz2 -C "${TEMPDIR}" .
rm -r "$TEMPDIR"
