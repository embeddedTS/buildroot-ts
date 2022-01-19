#!/bin/bash -e

TEMPDIR=$(mktemp -d)
mkdir "${TEMPDIR}"/boot/
cp "${BINARIES_DIR}"/{*.dtb,zImage,rootfs.cpio.uboot} "${TEMPDIR}"/boot/
cp "${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/ts7800v2-usbprod/scripts/tsinit.source "${TEMPDIR}"

echo "Generating U-Boot scripts"
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.scr
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.ub

# Scripts used for capturing/writing images
cp "${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/ts7800v2-usbprod/scripts/blast.sh "${TEMPDIR}/"
cp "${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/usbprod-common/scripts/blast_funcs.sh "${TEMPDIR}/"
cp "${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/usbprod-common/scripts/sanitize_linux_rootfs.sh "${TEMPDIR}/"

# Create output tarball
tar cjf "${BINARIES_DIR}"/ts7800v2-usb-image-replicator-rootfs.tar.bz2 -C "${TEMPDIR}" .

# Create output image
# Based on genimage.sh from Buildroot

GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
rm -rf "${GENIMAGE_TMP}"

genimage \
  --rootpath "${TEMPDIR}" \
  --tmppath "${GENIMAGE_TMP}" \
  --inputpath "${BINARIES_DIR}" \
  --outputpath "${BINARIES_DIR}" \
  --config ""${BR2_EXTERNAL_TECHNOLOGIC_PATH}"/board/ts7800v2-usbprod/scripts/genimage.cfg"


rm -r "${TEMPDIR}"
