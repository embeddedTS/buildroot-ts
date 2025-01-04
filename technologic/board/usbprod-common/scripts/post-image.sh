#!/bin/bash -e

PLAT="${2}"
if [ -z "${PLAT}" ]; then
	echo "Error! Platform not specified!"
	exit 1
fi
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

# Copies any non-kernel files that might have been setup there, e.g. FPGA bin
# This will fail when no files are present, so, check for files first that
# way any real copy errors will bubble back up
if [ -n "$(ls -A "${TARGET_DIR}/boot/"* 2>/dev/null)" ]; then
	cp "${TARGET_DIR}"/boot/* "${TEMPDIR}"/boot/
fi

echo "Generating U-Boot scripts"
# Create U-Boot output scripts. For the most compatibility we first look to see
# what the source file in the PLAT_SCRIPTS dir is. Then from there, create a
# compiled U-Boot script file.

# If the source is boot.source, the output will always need to be /boot/boot.scr
# However, some platforms through their development history might be looking for
# /boot/boot.ub, so create this as well.
if [ -f "${PLAT_SCRIPTS}/boot.source" ]; then
	cp "${PLAT_SCRIPTS}/boot.source" "${TEMPDIR}"/boot/

	# This platform needs boot.scr in same folder as kernel, FDT, ramdisk
	mkimage -A arm -T script -C none -n 'boot' \
		-d "${TEMPDIR}"/boot/boot.source "${TEMPDIR}"/boot/boot.scr
	mkimage -A arm -T script -C none -n 'boot' \
		-d "${TEMPDIR}"/boot/boot.source "${TEMPDIR}"/boot/boot.ub

# If the source is tsinit.source, then the output could need to be either
# /tsinit.ub or /tsinit.scr, depending on the platform. So we create both just
# to ensure broadest compatibility.
elif [ -f "${PLAT_SCRIPTS}/tsinit.source" ]; then
	cp "${PLAT_SCRIPTS}/tsinit.source" "${TEMPDIR}"

	mkimage -A arm -T script -C none -n 'boot' \
		-d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.scr
	mkimage -A arm -T script -C none -n 'boot' \
		-d "${TEMPDIR}"/tsinit.source "${TEMPDIR}"/tsinit.ub
fi

# Scripts used for capturing/writing images
cp "${PLAT_SCRIPTS}/blast.sh" "${TEMPDIR}/"
cp "${COMM_SCRIPTS}/README.txt" "${TEMPDIR}/"
cp "${COMM_SCRIPTS}/blast_funcs.sh" "${TEMPDIR}/"
cp "${COMM_SCRIPTS}/sanitize_linux_rootfs.sh" "${TEMPDIR}/"

# If post-image-extra.sh exists for this plat, execute it with ${TMPDIR} as the
# argument so it can do any additional work.
if [ -x "${PLAT_SCRIPTS}/post-image-extra.sh" ]; then
	"${PLAT_SCRIPTS}"/post-image-extra.sh "${PLAT_SCRIPTS}" "${TEMPDIR}/"
fi

# Remove old files before re-building output images
rm -f "${TAR_PATH}"* "${IMG_PATH}"*

# Create output files
tar cf "${TAR_DATE_PATH}.tar" -C "${TEMPDIR}" .
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
