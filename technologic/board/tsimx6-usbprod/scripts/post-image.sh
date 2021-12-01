#!/bin/bash -e


TEMPDIR=$(mktemp -d)
mkdir "${TEMPDIR}"/boot/
cp "${BINARIES_DIR}"/{*.dtb,uImage,rootfs.cpio.uboot} "${TEMPDIR}"/boot/
cp "${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/tsimx6-usbprod/scripts/tsinit.source "${TEMPDIR}"
# Copies any non-kernel files that might have been setup there, e.g. FPGA bin
cp "${TARGET_DIR}"/boot/* "${TEMPDIR}"/boot/

echo "Generating U-Boot scripts"
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.scr
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.ub

cp "${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/tsimx6-usbprod/scripts/blast.sh "${TEMPDIR}"/
tar cjf "${BINARIES_DIR}"/tsimx6-usb-production-rootfs.tar.bz2 -C "${TEMPDIR}" .

rm -r "$TEMPDIR"
