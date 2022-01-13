#!/bin/bash -e

TEMPDIR=$(mktemp -d)
mkdir "${TEMPDIR}"/boot/
cp "${BINARIES_DIR}"/{*.dtb,zImage,rootfs.cpio.gz} "${TEMPDIR}"/boot/
cp "${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/tsimx6ul-usbprod/scripts/tsinit.source "${TEMPDIR}"

echo "Generating U-Boot scripts"
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.scr
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.ub

# Scripts used for capturing/writing images
cp "${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/tsimx6ul-usbprod/scripts/blast.sh "${TEMPDIR}/"
cp "${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/usbprod-common/scripts/blast_funcs.sh "${TEMPDIR}/"
cp "${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/usbprod-common/scripts/sanitize_linux_rootfs.sh "${TEMPDIR}/"

# Create output tarball
tar cjf "${BINARIES_DIR}"/tsimx6ul-usb-production-rootfs.tar.bz2 -C "${TEMPDIR}" .

rm -r "$TEMPDIR"
