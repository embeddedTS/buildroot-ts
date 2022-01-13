#!/bin/sh

# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2021-2022 Technologic Systems, Inc. dba embeddedTS

err_exit() {
	echo "${1}" >> /tmp/failed
	exit
}

### Function to determine decompression to use based on name
### This is because busybox tar does not seem to correctly decompress
### arbitrary compression.
###
### Note that this depends on file extension rather than actually IDing the
### file's magic and will not work correctly if file is mis-named!
# Args
# 1) Full or relative filename with extension
# Returns command to use
# Use
# CMD=$(get_stream_decomp "/path/to/file.tar.bz2")
# ${CMD} can then be used to stream decompress the file to stdout

get_stream_decomp() {
	FILE_PATH="${1}"


	BASE=$(basename "${FILE_PATH}")
	EXTENSION="${BASE##*.}"
	case "${EXTENSION}" in
		"bz2")
			CMD="bzcat"
			;;
		"xz")
			CMD="xzcat"
			;;
		"gz")
			CMD="gunzip -c"
			;;
		# If extension isn't a compression extension, then just cat it
		"tar"|"dd")
			CMD="cat"
			;;
		*)
			err_exit "${FILE_PATH} unknown compression"
			;;
	esac

	echo "${CMD}"
}

### Function to work with a single partition on a disk with a tarball for
### its contents. This function will wipe the partition table on the dest.
### device, recreate a single partition for the whole lenght of disk,
### unpack the tarball, and optionally verify it
###
### This particular function is set up to always assume whole disk, MBR
### partition format, and ext4 (with caveats on features due to U-Boot support
### on relevant platforms)
###
### TODO: At some point in the future, remove dependency on the part prefix arg
# Args:
# 1) Source file, the full path to the tarball
# 2) Dest. device node, e.g. /dev/sda, /dev/mmcblk1
# 3) Dest. part prefix, e.g. for /dev/sdb1, part prefix is "", for /dev/mmcblk1p1
#      part prefix is "p"
# 4) Human readable part name, e.g. "sd", "emmc", "sata" Used for logging
# 5) Filesystem type [optional]
#      May be one of:
#      ext3
#      ext4compat [default] (This adds the options ^metadata_csum,^64bit to ext4
#                            which is needed on older U-Boot versions that don't
#                            support these options of ext4)
#      ext4
# Use
# untar_image "/path/sdimage.tar.xz" "/dev/mmcblk1" "p" "sd"

untar_image() {

	SRC_TARBALL=${1}
	DST_DEV=${2}
	DST_DEV_PART=${2}${3}
	DST_MOUNT=$(mktemp -d)
	HUMAN_NAME=${4}
	FILESYSTEM="${5:-ext4compat}"
	
	echo "======= Writing ${HUMAN_NAME} filesystem ========"

	(
		set -x

		# NOTE: This would be where modifications could be made to
		# cause this process to set enhanced and high-reliability
		# modes of eMMC devices.

		# Erase and recreate partition table from scratch
		# Assume SD eraseblock size of 4 MiB, align to that.
		# Use MBR format partition table
		# Use whole disk
		# Set ext4 NOTE! see mkfs.ext4 below!
		dd if=/dev/zero of="${DST_DEV}" bs=512 count=1 || err_exit "clear MBR"
		parted -s -a optimal "${DST_DEV}" mklabel msdos || err_exit "mklabel ${DST_DEV}"
		parted -a optimal "${DST_DEV}" mkpart primary ext4 4MiB 100% || err_exit "mkpart ${DST_DEV}"

		case "${FILESYSTEM}" in
			"ext2")
				CMD="mkfs.ext2"
				;;
			"ext3")
				CMD="mkfs.ext3"
				;;
			# U-Boot on compatible platforms does not support the
			# checksum and 64bit attrbites of ext4. Turn these off
			# when making the filesystem
			"ext4compat")
				CMD="mkfs.ext4 -O ^metadata_csum,^64bit"
				;;
			"ext4")
				CMD="mkfs.ext4"
				;;
			*)
				err_exit "invalid filesystem ${FILESYSTEM} on ${HUMAN_NAME}"
				;;
		esac
		${CMD} "${DST_DEV_PART}"1 -q -F || err_exit "mke2fs ${DST_DEV}"
		mount "${DST_DEV_PART}"1 "${DST_MOUNT}" || err_exit "mount ${DST_DEV}"

		CMD=$(get_stream_decomp "${SRC_TARBALL}")

		${CMD} "${SRC_TARBALL}" | tar -x -C "${DST_MOUNT}" || err_exit "untar ${DST_DEV}"
		sync

		if [ -e "${DST_MOUNT}/md5sums.txt" ]; then
			# Drop caches so we have to reread all files
			echo 3 > /proc/sys/vm/drop_caches
			(
			cd "${DST_MOUNT}"
			md5sum --quiet -c md5sums.txt > /tmp/logs/"${HUMAN_NAME}"-md5sum || err_exit "${DST_DEV} FS verify"
			)
		fi

		umount "${DST_MOUNT}" || err_exit "umount ${DST_MOUNT}"
		rmdir "${DST_MOUNT}"
	) > /tmp/logs/"${HUMAN_NAME}"-writefs 2>&1 &
}

### Function to write disk image to destination device
### This function will accept a compressed disk image and will write the whole
### image to a single disk.
### This process will destroy all data on the target disk
# Args:
# 1) Source .dd image full name, e.g. "/path/to/image.dd.xz"
# 2) Dest. device node, e.g. "/dev/mmcblk0"
# 3) Human readable name, e.g. "emmc" Used for logging purposes.

dd_image() {
	SRC_DD=${1}
	DST_DEV=${2}
	HUMAN_NAME=${3}

	echo "======= Writing ${HUMAN_NAME} disk image ========"
	(
		set -x

		CMD=$(get_stream_decomp "${SRC_DD}")
		${CMD} "${SRC_DD}" | dd bs=4M of="${DST_DEV}" conv=notrunc,fsync || err_exit "${DST_DEV} dd write"
		BYTES=$(${CMD} "${SRC_DD}" | wc -c)

		MD5SUM="${SRC_DD%%.*}"
		MD5SUM="${MD5SUM}.dd.md5"
		if [ -e "${MD5SUM}" ]; then
			EXPECTED=$(cut -f 1 -d ' ' "${MD5SUM}")
			ACTUAL=$(head "${DST_DEV}" -c "${BYTES}" | md5sum | cut -f 1 -d ' ')
			if [ "$ACTUAL" != "$EXPECTED" ]; then
				echo "${DST_DEV} dd verify" >> /tmp/failed
			fi
		fi
	) > /tmp/logs/"${HUMAN_NAME}"-writeimage 2>&1 &
}

### Function to create either a .dd image or a tarball from a source disk
### The final files are compressed with xz
### The source disk is captured bit for bit, the Linux rootfs partition
###   mounted, sanitized of unique data, temporary files, logs, etc., prepared
###   for first boot on a new device, given a custom date, and all files
###   md5summed.
### If the source disk contains only a single partition, the files are then
###   added to a single tarball, which is compressed and md5summed as well, and
###   then the source disk capture is removed.
### NOTE! If a custom partition size is used here, this will not be replicated
###   on other devices if our stock capture/replication process is used! If
###   such support is needed, then be sure to create at least one other
###   partition in the source disk image.
### If the source disk contains multiple partitions, then the whole disk image
###   will be md5summed, compressed, and that md5summed. 
###
### WARNING! The USB drive used must have enough space for existing files,
###   uncompressed .dd, and compression ouput. If there is not, this process
###   will fail
###
# Args
# 1) Source device, whole disk, e.g. /dev/mmcblk0
# 2) Dest. path, e.g. /mnt/usb, this path will be used for source image capture
#      as well as final file output destination
# 3) Dest. name, e.g. "sd" "emmc" etc. Used for naming the final output, e.g.
#      "sdimage.tar.xz"
# 4) [Optional] The partition number of the Linux rootfs, 1 if not set.
#      NOTE! This is the actual partition number, not the count on disk!
#      e.g. 5 == the first extended MBR partition, even if it is the only
#      partition on disk.
# Use:
# capture_img_or_tar_from_disk "/dev/mmcblk1" "/mnt/usb" "sd" 
# capture_img_or_tar_from_disk "/dev/mmcblk2" "/mnt/nfs" "emmc" "2"

capture_img_or_tar_from_disk() {

	SRC_DEV="${1}"
	DST_PATH="${2}"
	NAME="${3}"
	IMG="${NAME}image.dd"
	TAR="${NAME}image.tar"
	DST_IMG="${DST_PATH}/${IMG}"
	DST_TAR="${DST_PATH}/${TAR}"
	PART="${4:-1}"
	

	echo "====== Capturing ${NAME} image from ${SRC_DEV} ======"
	(
		set -x

		# Using cat has shown to be faster than dd
		cat "${SRC_DEV}" > "${DST_IMG}" || err_exit "capture from ${DST_IMG}"
		sync

		TMP_DIR=$(mktemp -d)

		# Get number of partitions on the source device
		PART_CNT=$(partx -g "${SRC_DEV}" | wc -l)

		# Get start of partition
		let linux_start=$(partx -rgo START -n "${PART}":"${PART}" "${DST_IMG}")*512
		LODEV=$(losetup -f)
		losetup -f -o "${linux_start}" "${DST_IMG}" || err_exit "losetup ${DST_IMG}"
		fsck "${LODEV}" -y || err_exit "fsck ${DST_IMG}"

		echo "Mounting partition ${PART} of disk image"
		mount "${LODEV}" "${TMP_DIR}"/ || err_exit "mount ${DST_IMG}"

		# Run prep image script against the mounted directory
		/mnt/usb/sanitize_linux_rootfs.sh "${TMP_DIR}"


		# If there is a single partition, then lets make a tarball
		# as opposed to a whole disk image to save time and space.
		if [ ${PART_CNT} -eq 1 ]; then
			# Subshell used becuase we are changing dirs
			(
			cd "${DST_PATH}" || err_exit "cd ${DST_PATH}"
			echo "Creating compressed tarball"
			tar cf "${TAR}" -C "${TMP_DIR}"/ . || err_exit "tar create ${TAR}"
			md5sum "${TAR}" > "${TAR}.md5" || err_exit "md5 ${TAR}.md5"
			xz -2 "${TAR}" || err_exit "compress ${TAR}"
			md5sum "${TAR}.xz" > "${TAR}.xz.md5" || err_exit "md5 ${TAR}.xz.md5"
			)
		else
			# Prep our existing .dd for better compression
			echo "Zeroing out free space in FS for better compression"
			dd if=/dev/zero of="${TMP_DIR}"/zerofile conv=fsync
			rm "${TMP_DIR}"/zerofile
		fi

		umount "${TMP_DIR}" || err_exit "umount ${DST_IMG}"
		losetup -d "${LODEV}" || err_exit "losetup destroy ${DST_IMG}"
		rmdir "${TMP_DIR}"

		# If we used a tarball, then remove the source image.
		# If a disk image, then compress and create output files
		if [ ${PART_CNT} -eq 1 ]; then
			rm "${DST_IMG}" || err_exit "rm ${DST_IMG}"
		else
			# Subshell is used because we are changing dirs
			# XXX: check errors here?
			(
			echo "Compressing and generating md5s"
			cd "${DST_PATH}" || err_exit "cd ${DST_PATH}"
			md5sum "${IMG}" > "${IMG}".md5 || err_exit "md5 ${IMG}.md5"
			xz -2 "${IMG}" || err_exit "compress ${IMG}"
			md5sum "${IMG}".xz > "${IMG}".xz.md5 || err_exit "md5 ${IMG}.xz.md5"
			)
		fi


	) > /tmp/logs/"${NAME}"-capture 2>&1

}
