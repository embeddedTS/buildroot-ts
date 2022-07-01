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

### Function to return the full file path to a specified disk partition.
### Converts input disk and part in to a path, handles block devices
### and files. Needed because some device paths use a partition prefix
### while others do not. e.g. /dev/mmcblk0p1 uses "p" while /dev/sdb1
### uses "".
###
### This code is almost verbatim from a similar function in growpart.
###
# Args
# 1) Disk, e.g. /dev/sdb, /dev/mmcblk0, etc.
# 2) Partition, e.g. 1, 2, 3
# Returns full path, e.g. /dev/mmcblk0p2, /dev/sdb1
# Use
# PART_PATH=$(get_diskpart_path "/dev/mmcblk0" 1)
# PART_PATH will contain "/dev/mmcblk0p1"

get_diskpart_path() {
	disk="$1"
	part="$2"
	dpart=""

	dpart="${disk}${part}" # disk and partition number
	if [ -b "$disk" ]; then
		if [ -b "${disk}p${part}" ] && [ "${disk%[0-9]}" != "${disk}" ]; then
			# for block devices that end in a number (/dev/nbd0)
			# the partition is "<name>p<partition_number>" (/dev/nbd0p1)
			dpart="${disk}p${part}"
		elif [ "${disk#/dev/loop[0-9]}" != "${disk}" ]; then
			# for /dev/loop devices, sfdisk output will be <name>p<number>
			# format also, even though there is not a device there.
			dpart="${disk}p${part}"
		fi
	else
		case "$disk" in
			# sfdisk for files ending in digit to <disk>p<num>.
			*[0-9]) dpart="${disk}p${part}";;
		esac
	fi

	echo "$dpart"
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
#      part prefix is "p"
# 3) Human readable part name, e.g. "sd", "emmc", "sata" Used for logging
# 4) Filesystem type [optional]
#      May be one of:
#      ext3
#      ext4compat [default] (This adds the options ^metadata_csum,^64bit to ext4
#                            which is needed on older U-Boot versions that don't
#                            support these options of ext4)
#      ext4
#      ext4gpt              (Creates a GPT table instead of MBR)
# Use
# untar_image "/path/sdimage.tar.xz" "/dev/mmcblk1" "sd"

untar_image() {

	SRC_TARBALL=${1}
	DST_DEV=${2}
	DST_MOUNT=$(mktemp -d)
	HUMAN_NAME=${3}
	FILESYSTEM="${4:-ext4compat}"
	
	echo "======= Writing ${HUMAN_NAME} filesystem ========"

	(
		set -x

		# NOTE: This would be where modifications could be made to
		# cause this process to set enhanced and high-reliability
		# modes of eMMC devices.

		case "${FILESYSTEM}" in
			"ext2")
				FS_FMT="ext2"
				FS_CMD="mkfs.ext2"
				PART_FMT="msdos"
				;;
			"ext3")
				FS_FMT="ext3"
				FS_CMD="mkfs.ext3"
				PART_FMT="msdos"
				;;
			# U-Boot on compatible platforms does not support the
			# checksum and 64bit attrbites of ext4. Turn these off
			# when making the filesystem
			"ext4compat")
				FS_FMT="ext4"
				FS_CMD="mkfs.ext4 -O ^metadata_csum,^64bit"
				PART_FMT="msdos"
				;;
			"ext4")
				FS_FMT="ext4"
				FS_CMD="mkfs.ext4"
				PART_FMT="msdos"
				;;
			"ext4gpt")
				FS_FMT="ext4"
				FS_CMD="mkfs.ext4"
				PART_FMT="gpt"
				;;
			*)
				err_exit "invalid filesystem ${FILESYSTEM} on ${HUMAN_NAME}"
				;;
		esac

		# Erase and recreate partition table from scratch
		# Assume SD eraseblock size of 4 MiB, align to that.
		# Use MBR format partition table
		# Use whole disk
		# Set ext4 NOTE! see mkfs.ext4 below!
		dd if=/dev/zero of="${DST_DEV}" bs=512 count=1 || \
		  err_exit "clear MBR"

		# Create new partition table that is PART_FMT
		parted -s -a optimal "${DST_DEV}" mklabel "${PART_FMT}" || \
		  err_exit "mklabel ${DST_DEV}"

		# Create a single primary partition
		parted -s -a optimal "${DST_DEV}" mkpart primary "${FS_FMT}" \
		  4MiB 100% || err_exit "mkpart ${DST_DEV}"

		# Set the first partition as bootable
		parted -s "${DST_DEV}" set 1 boot on || \
		  err_exit "set boot $(get_diskpart_path "${DST_DEV}" 1)"

		# Format the first partition according to FS_CMD
		${FS_CMD} "$(get_diskpart_path "${DST_DEV}" 1)" -q -F \
		  || err_exit "mke2fs ${DST_DEV}"

		# Finally, mount partition
		mount "$(get_diskpart_path "${DST_DEV}" 1)" "${DST_MOUNT}" || \
		  err_exit "mount ${DST_DEV}"

		# Get the correct command to stream decompress the tarball
		# and run it
		CMD=$(get_stream_decomp "${SRC_TARBALL}")
		${CMD} "${SRC_TARBALL}" | tar -x -C "${DST_MOUNT}" || \
		  err_exit "untar ${DST_DEV}"

		sync

		if [ -e "${DST_MOUNT}/md5sums.txt" ]; then
			# Drop caches so we have to reread all files
			echo 3 > /proc/sys/vm/drop_caches
			(
			cd "${DST_MOUNT}" || err_exit "cd ${DST_MOUNT}"
			md5sum --quiet -c md5sums.txt > \
			  /tmp/logs/"${HUMAN_NAME}"-md5sum || \
			  err_exit "${DST_DEV} FS verify"
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
		${CMD} "${SRC_DD}" | dd bs=4M of="${DST_DEV}" conv=notrunc,fsync \
		  || err_exit "${DST_DEV} dd write"

		MD5SUM="${SRC_DD%%.*}"
		MD5SUM="${MD5SUM}.dd.md5"
		if [ -e "${MD5SUM}" ]; then
			BYTES=$(${CMD} "${SRC_DD}" | wc -c)
			EXPECTED=$(cut -f 1 -d ' ' "${MD5SUM}")
			ACTUAL=$(head "${DST_DEV}" -c "${BYTES}" | md5sum | \
			  cut -f 1 -d ' ')
			if [ "$ACTUAL" != "$EXPECTED" ]; then
				echo "${DST_DEV} dd verify" >> /tmp/failed
			fi
		fi
	) > /tmp/logs/"${HUMAN_NAME}"-writeimage 2>&1 &
}

### Function to create either a .dd image or a tarball from a source disk
### The final files are compressed with xz
### If the source disk contains only a single partition, then a sparse temp
###   file is created on the destination folder. This is then mounted,
###   along with the source rootfs partition (which is mounted ro,noatime),
###   and the source filesystem is captured to the sparse file backed mount.
###   This is done with a tar pipeline to ensure all files are captured as
###   they should be.
### If the source disk is multiple partitions, the source disk is captured
###   bit for bit, the source rootfs partition is mounted.
### At this point, the data to be captured is sanitized of unique data,
###   temporary files, logs, etc., prepared for first boot on a new device,
###   given a custom date stamp in a file, and all files are md5summed.
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

		# Get number of partitions on the source device
		PART_CNT=$(partx -g "${SRC_DEV}" | wc -l)

		TMP_DIR=$(mktemp -d)

		# If there is a single partition, we're going to end up making
		# a tarball. To reduce repeated code, we set up a mount point
		# backed by a sparse file with the SRC_DEV's disk contents here.
		# Then, this path can be passed to the sanitization script
		# regardless of it being the sparse backed or disk image loopback.
		if [ ${PART_CNT} -eq 1 ]; then

			# Make a temporary file on ${DST_PATH} that will become
			# our loopback mount
			TMP_DISK=$(mktemp -p "${DST_PATH}")

			# Make that temp file a sparse file with a size that is
			# 100 MB smaller than the remaining space on the DST_PATH
			truncate --size \
			  "$(stat -f "${DST_PATH}" -c '(%a*%S/1024)-100000' | bc)K" \
			  "${TMP_DISK}"

			# Make a filesystem on the sparse file
			# XXX: Currently just hard-coding ext4, this could potentially
			# be problematic on some platforms?
			mkfs.ext4 "${TMP_DISK}" || err_exit "mkfs temp disk"

			# Mount the temp disk to the temp dir
			mount -oloop "${TMP_DISK}" "${TMP_DIR}"

			# Now, need to mount SRC PART to a separate dir
			TMP_SRC_DIR=$(mktemp -d)
			mount -oro,noatime \
			  "$(get_diskpart_path "${SRC_DEV}" "${PART}")" \
			  "${TMP_SRC_DIR}" || err_exit "mount SRC PART for tarball"

			# Copy source disk filesystem to our sparse file backed
			# mount location. Use tar pipeline to ensure EVERY file
			# property, permission, etc, is coped intact
			tar -cf - -C "${TMP_SRC_DIR}"/ . | tar x -C "${TMP_DIR}" \
			  || err_exit "copy SRC contents to TMP DST"

			# Unmount the SRC disk, we should no longer need this.
			# At this point, TMP_DIR should now be able to be passed
			# through the sanitize script just the same as if it were
			# a loopmount part from the whole disk.
			umount "${TMP_SRC_DIR}" || err_exit "umount TMP SRC DIR"
		else

			# Capture whole disk image
			# Using cat has shown to be faster than dd
			cat "${SRC_DEV}" > "${DST_IMG}" || \
			  err_exit "capture from ${DST_IMG}"
			sync

			# Get start of partition
			let linux_start=$(partx -rgo START -n "${PART}":"${PART}" \
			  "${DST_IMG}")*512
			LODEV=$(losetup -f)
			losetup -f -o "${linux_start}" "${DST_IMG}" || \
			  err_exit "losetup ${DST_IMG}"
			fsck "${LODEV}" -y || err_exit "fsck ${DST_IMG}"

			echo "Mounting partition ${PART} of disk image"
			mount "${LODEV}" "${TMP_DIR}"/ || err_exit "mount ${DST_IMG}"
		fi

		# Run prep image script against the mounted directory
		/mnt/usb/sanitize_linux_rootfs.sh "${TMP_DIR}"


		# If there is a single partition, then lets make a tarball
		# as opposed to a whole disk image to save time and space.
		if [ ${PART_CNT} -eq 1 ]; then
			echo "Creating compressed tarball"
			tar cf "${DST_TAR}" -C "${TMP_DIR}"/ . || \
			  err_exit "tar create ${TAR}"
			# This two-step is needed, and repeated, because we want
			# the .md5 file to not have any relative paths
			MD5SUM=$(md5sum "${DST_TAR}") || err_exit "md5 ${TAR}"
			MD5SUM=$(echo "${MD5SUM}" | cut -f 1 -d ' ')
			echo "${MD5SUM}  ${TAR}" > "${DST_TAR}.md5"

			xz -2 "${DST_TAR}" || err_exit "compress ${TAR}"
			MD5SUM=$(md5sum "${DST_TAR}.xz") || \
			  err_exit "md5 ${TAR}.xz"
			MD5SUM=$(echo "${MD5SUM}" | cut -f 1 -d ' ')
			echo "${MD5SUM}  ${TAR}.xz" > "${DST_TAR}.xz.md5"
		else
			# Prep our existing .dd for better compression
			echo "Zeroing out free space in FS for better compression"
			dd if=/dev/zero of="${TMP_DIR}"/zerofile conv=fsync
			rm "${TMP_DIR}"/zerofile
		fi

		umount "${TMP_DIR}" || err_exit "umount ${DST_IMG}"
		rmdir "${TMP_DIR}"

		# If we used a tarball, then remove the sparse file backing
		# the loopback.
		# If a disk image, then compress and create output files
		if [ ${PART_CNT} -eq 1 ]; then
			rm "${TMP_DISK}" || err_exit "rm ${TMP_DISK}"
		else
			echo "Compressing and generating md5s"
			losetup -d "${LODEV}" || err_exit "losetup destroy ${LODEV}"

			# This two-step is needed, and repeated, because we want
			# the .md5 file to not have any relative paths
			MD5SUM=$(md5sum "${DST_IMG}") || err_exit "md5 ${IMG}"
			MD5SUM=$(echo "${MD5SUM}" | cut -f 1 -d ' ')
			echo "${MD5SUM}  ${IMG}" > "${DST_IMG}.md5"

			xz -2 "${DST_IMG}" || err_exit "compress ${IMG}"
			MD5SUM=$(md5sum "${DST_IMG}.xz") || \
			  err_exit "md5 ${IMG}.xz"
			MD5SUM=$(echo "${MD5SUM}" | cut -f 1 -d ' ')
			echo "${MD5SUM}  ${IMG}.xz" > "${DST_IMG}.xz.md5"
		fi


	) > /tmp/logs/"${NAME}"-capture 2>&1

}

### Blink the LEDs in a loop based on status markers
# Currently only has three states, running [default], completed, and failed
# The markers are /tmp files names /tmp/failed and /tmp/completed
# In general, either the startup scripts should run this, or, if that
# doesn't make sense, then blash.sh can start it.
# The blast.sh file should have an led_init() function define that
# defines the following functions
# redled_on, redled_off, grnled_on, grnled_off
# and then calls this loop. The toplevel call to led_init() should be
# backgrounded.
# The /tmp/completed file should always be created at the end of blast.sh
# to denote the process is done. However, if /tmp/failed is created along
# the way then the blink pattern for that will take precedence
#
# An example of how to set up the led_init() function:
## led_init() {
##	redled_on() { <command> ; }
##	redled_off() { <command> ; }
##	grnled_on() { <command> ; }
##	grnled_off() { <command> ; }
##
##	led_blinkloop
## }
led_blinkloop() {
	while true; do
		# Running state
		if [ ! -e /tmp/completed ]; then
			redled_on
			grnled_on
			sleep 0.25
			grnled_off
			sleep 1
		elif [ -e /tmp/failed ]; then
			grnled_off
			redled_on
			sleep 1
			redled_off
			sleep 1
		elif [ -e /tmp/completed ]; then
			redled_off
			grnled_on
			sleep 1
			grnled_off
			sleep 1
		fi
	done
}
