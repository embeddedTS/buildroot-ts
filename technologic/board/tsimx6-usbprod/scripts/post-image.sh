#!/bin/bash -e

PLAT="tsimx6"
TAR_BASE="${PLAT}-usb-image-replicator-rootfs"
IMG_BASE="${PLAT}-usb-image-replicator"
TAR_PATH="${BINARIES_DIR}/${TAR_BASE}"
IMG_PATH="${BINARIES_DIR}/${IMG_BASE}"
DATE=$(date +"%Y%m%d")
TAR_DATE_PATH="${TAR_PATH}-${DATE}"
IMG_DATE_PATH="${IMG_PATH}-${DATE}"
PLAT_SCRIPTS="${BR2_EXTERNAL_TECHNOLOGIC_PATH}/board/${PLAT}-usbprod/scripts"
COMM_SCRIPTS="${BR2_EXTERNAL_TECHNOLOGIC_PATH}/board/usbprod-common/scripts"


TEMPDIR=$(mktemp -d)
mkdir "${TEMPDIR}"/boot/
cp "${BINARIES_DIR}"/{*.dtb,*Image,rootfs.cpio.*} "${TEMPDIR}"/boot/
cp "${PLAT_SCRIPTS}/tsinit.source" "${TEMPDIR}"

# Copies any non-kernel files that might have been setup there, e.g. FPGA bin
cp "${TARGET_DIR}"/boot/* "${TEMPDIR}"/boot/

echo "Generating U-Boot scripts"
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.scr
mkimage -A arm -T script -C none -n 'boot' -d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.ub

# Scripts used for capturing/writing images
cp "${PLAT_SCRIPTS}/blast.sh" "${TEMPDIR}/"
cp "${COMM_SCRIPTS}/blast_funcs.sh" "${TEMPDIR}/"
cp "${COMM_SCRIPTS}/sanitize_linux_rootfs.sh" "${TEMPDIR}/"

# Remove old files before re-building output images
rm -f ${TAR_PATH}* ${IMG_PATH}*

# Create output files
tar chf "${TAR_DATE_PATH}.tar" -C "${TEMPDIR}" .
md5sum "${TAR_DATE_PATH}.tar" > "${TAR_DATE_PATH}.tar.md5"
xz -2 "${TAR_DATE_PATH}.tar"
ln -sf "${TAR_BASE}-${DATE}.tar.xz" "${TAR_PATH}.tar.xz"

# Create output image
# Based on genimage.sh from Buildroot

GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"
rm -rf "${GENIMAGE_TMP}"

genimage \
  --rootpath "${TEMPDIR}" \
  --tmppath "${GENIMAGE_TMP}" \
  --inputpath "${BINARIES_DIR}" \
  --outputpath "${BINARIES_DIR}" \
  --config "${PLAT_SCRIPTS}/genimage.cfg"

# Create output files
mv "${IMG_PATH}.dd" "${IMG_DATE_PATH}.dd"
md5sum "${IMG_DATE_PATH}.dd" > "${IMG_DATE_PATH}.dd.md5"
xz -2 "${IMG_DATE_PATH}.dd"
ln -sf "${IMG_BASE}-${DATE}.dd.xz" "${IMG_PATH}.dd.xz"


rm -r "${TEMPDIR}"
