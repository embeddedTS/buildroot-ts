#!/bin/sh

# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2021-2022 Technologic Systems, Inc. dba embeddedTS

err_exit() {
	echo "${1}" >> /tmp/failed
	exit
}

# On something deemed a criticial failure, e.g. if power is removed after
# this point in time the unit may not boot back up, create a crit-failed
# file (with a rapid blinking pattern) and also a failed file so any
# other systems looking for the default failed will get the same message
crit_exit() {
	echo "${1}" >> /tmp/crit-failed
	err_exit "${1}"
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

### Function to get all option files from a directory and export them
### as environment variables that can be checked.
# Args
# 1) The path to look for option files
# Use

get_env_options() {
	OPT_PATH="${1}"

	for file in "${OPT_PATH}"/IR_*; do
		file=$(basename ${file})
		[ "${file}" = "IR_*" ] && continue
		echo "Using Option: ${file}"
		eval "${file}=1"
		eval "export ${file}"
	done
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
# Args:
# 1) Source file, the full path to the tarball
# 2) Dest. device node, e.g. /dev/sda, /dev/mmcblk1
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
		set -x -o pipefail

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
		${CMD} "${SRC_TARBALL}" | tar -xh -C "${DST_MOUNT}" || \
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
		# In order to save CPU and IO time on decompressing the source
		# file twice, use some FIFO magic to get the length of the image
		# while we are writing it to disk. This involves a couple of temp
		# files and directories that later get cleaned up.

		set -x -o pipefail

		BYTES_CNT_F=$(mktemp)
		FIFO_DIR=$(mktemp -d)

		# Create FIFO and start wc process
		mkfifo "${FIFO_DIR}"/fifo || err_exit "dd mkfifo"
		wc -c < "${FIFO_DIR}"/fifo > "${BYTES_CNT_F}" & WC_PID=$!

		# Get the correct command to stream decompress, then run the
		# file through tee to our wc process above and then in to the
		# dd process
		# XXX: Consider replacing dd with cat or redirect and sync?
		CMD=$(get_stream_decomp "${SRC_DD}")
		${CMD} "${SRC_DD}" | tee "${FIFO_DIR}"/fifo | \
		  dd bs=4M of="${DST_DEV}" conv=fsync \
		  || err_exit "${DST_DEV} dd write"
		wait $WC_PID

		MD5SUM="${SRC_DD%%.*}"
		MD5SUM="${MD5SUM}.dd.md5"
		if [ -e "${MD5SUM}" ]; then
			BYTES=$(cat "${BYTES_CNT_F}")
			EXPECTED=$(cut -f 1 -d ' ' "${MD5SUM}")
			ACTUAL=$(head "${DST_DEV}" -c "${BYTES}" | md5sum | \
			  cut -f 1 -d ' ')
			if [ "$ACTUAL" != "$EXPECTED" ]; then
				echo "${DST_DEV} dd verify" >> /tmp/failed
			fi
		fi

		# Clean up fifo and temp files
		rm -rf "${FIFO_DIR}" || err_exit "dd rm fifo dir"
		rm "${BYTES_CNT_F}" || err_exit "dd rm bytes count file"

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
		set -x -o pipefail

		# Ensure kernel loop driver is loaded
		modprobe loop || err_exit "modprobe loop"

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
			tar -cf - -C "${TMP_SRC_DIR}"/ . | tar xh -C "${TMP_DIR}" \
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
		# XXX: This is a hardcoded path and could be a problem
		/mnt/usb/sanitize_linux_rootfs.sh "${TMP_DIR}"


		# If there is a single partition, then lets make a tarball
		# as opposed to a whole disk image to save time and space.
		if [ ${PART_CNT} -eq 1 ]; then
			echo "Creating tarball"
			tar cf "${DST_TAR}" -C "${TMP_DIR}"/ . || \
			  err_exit "tar create ${TAR}"
			# This two-step is needed, and repeated, because we want
			# the .md5 file to not have any relative paths
			MD5SUM=$(md5sum "${DST_TAR}") || err_exit "md5 ${TAR}"
			MD5SUM=$(echo "${MD5SUM}" | cut -f 1 -d ' ')
			echo "${MD5SUM}  ${TAR}" > "${DST_TAR}.md5"

			# Don't compress the output file if IR_NO_COMPRESS
			# env var is defined
			if [ -n "${IR_NO_COMPRESS}" ]; then
				echo "Skipping compression"
			else
				echo "Compressing tarball"
				xz -2 "${DST_TAR}" || err_exit "compress ${TAR}"
			fi
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
			echo "Creating final image"
			losetup -d "${LODEV}" || err_exit "losetup destroy ${LODEV}"

			# This two-step is needed, and repeated, because we want
			# the .md5 file to not have any relative paths
			MD5SUM=$(md5sum "${DST_IMG}") || err_exit "md5 ${IMG}"
			MD5SUM=$(echo "${MD5SUM}" | cut -f 1 -d ' ')
			echo "${MD5SUM}  ${IMG}" > "${DST_IMG}.md5"

			# Don't compress the output file if IR_NO_COMPRESS
			# env var is defined
			if [ -n "${IR_NO_COMPRESS}" ]; then
				echo "Skipping compression"
			else
				echo "Compressing image"
				xz -2 "${DST_IMG}" || err_exit "compress ${IMG}"
			fi
		fi


	) > /tmp/logs/"${NAME}"-capture 2>&1

}

### Wizard Update
### Used to update the supervisory microcontroller on some platforms.
### This tool will properly error on incompatible devices
# Args:
# 1) Update file
wizard_update() {
	FILE="${1}"

	echo "====== Updating Supervisory Microcontroller (Wizard) ======"
	(
		set -x -o pipefail

		tssupervisorupdate --info || crit_exit "wizard info"
		tssupervisorupdate -u "${FILE}" || crit_exit "wizard update"
	) > /tmp/logs/wizard-update 2>&1
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
		elif [ -e /tmp/crit-failed ]; then
			grnled_off
			redled_on
			sleep 0.12
			redled_off
			sleep 0.12
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

### Handle writing U-Boot binary blobs to disk
# This can handle both writing a single image, or a pair of images, e.g. separate
# U-Boot binary and SPL blob. As well as doing a readback verification using a
# similarly named .md5 file. If the block device name has an associated `force_ro`
# file such as boot* partitions on eMMC it will automatically set the device to
# read/write and then back to read-only.
#
# When specifying offsets for the image (and SPL) the offsets are specified
# IN 512 BYTE BLOCKS! This makes writing a bit faster and every platform in the
# the future should all be fine with this alignment.
# Args:
# 1) U-Boot device name, not the full path, e.g. mtdblock0, mmcblk1boot0, etc.
#    NOTE! This assumes the the device is a device node!
# 2) Full path to U-Boot image (this is the .imx, .bin, etc.)
#    If a corresponding .md5 file exists, that is used to verify reading back
# 3) Start of where to place the image IN 512 BYTE BLOCKS! e.g. 0 is 0*512 bytes,
#    2 is 2*512 bytes, etc.
# 4) [Optional] Full path to U-Boot SPL
#    If a corresponding .md5 file exists, that is used to verify reading back
# 5) [Required if SPL] Start of where to place the SPL IN 512 BYTE BLOCKS!
#    e.g. 0 is 0*512 bytes,
# Use:
# write_uboot "mtdblock0" "/mnt/usb/u-boot.bin" 2 "/mnt/usb/SPL" 400
# write_uboot "mmbclk0boot0" "/mnt/usb/u-boot.bin" 0

write_uboot() {
	UBOOT_DN="${1}"
	UBOOT_IMG="${2}"
	UBOOT_IMG_OFFS="${3}"
	UBOOT_SPL="${4:--1}"
	UBOOT_SPL_OFFS="${5:--1}"

        echo "========== Writing new U-boot image =========="
        (
		set -x -o pipefail

		# If the device name (DN) is eMMC then we likely need to unlock
		# the boot partition. If the force_ro file exists, then we just
		# blindly poke it.
		if [ -e "/sys/block/${UBOOT_DN}/force_ro" ]; then
			echo 0 > "/sys/block/${UBOOT_DN}/force_ro"
		fi

		# Write image to offset. Always assumes a bs of 512!
		# This does not error on write failure, maybe it should?
		dd bs=512 seek="${UBOOT_IMG_OFFS}" if="${UBOOT_IMG}" \
			of="/dev/${UBOOT_DN}" conv=fsync || \
			crit_exit "U-Boot img write"

		# If provided, write SPL to its offset. Always assumes a bs of 512!
		if [ "${UBOOT_SPL}" != "-1" ] && [ "${UBOOT_SPL_OFFS}" != "-1" ]; then
			dd bs=512 seek="${UBOOT_SPL_OFFS}" if="${UBOOT_SPL}" \
				of="/dev/${UBOOT_DN}" conv=fsync || \
				crit_exit "U-Boot spl write"
		fi

		# Flush any buffer cache
		sync
		echo 3 > /proc/sys/vm/drop_caches

		if [ -e "/sys/block/${UBOOT_DN}/force_ro" ]; then
			echo 1 > "/sys/block/${UBOOT_DN}/force_ro"
		fi

		# Check md5sum of image
		if [ -e "${UBOOT_IMG}.md5" ]; then
                        BYTES=$(wc -c "${UBOOT_IMG}" | cut -d ' ' -f 1)
                        EXPECTED=$(cut -f 1 -d ' ' "${UBOOT_IMG}.md5")
			# This looks annoyingly convoluted because it is.
			# In order to not get bogged down by reading very slowly
			# we read a large chunk, jump to where we need to start
			# then read the exact byte count. So we arn't using a bs
			# of 1 on the whole disk. It could probably be optimized
			# but it works.
                        ACTUAL=$(dd if="/dev/${UBOOT_DN}" bs=4M | \
                          dd skip="${UBOOT_IMG_OFFS}" bs=512 | \
			  dd bs=1 count="${BYTES}" | \
			  md5sum | \
                          cut -f 1 -d ' ')
                        if [ "${ACTUAL}" != "${EXPECTED}" ]; then
				crit_exit "U-Boot image verify"
                        fi
		fi

		# Check md5sum of SPL
		if [ -e "${UBOOT_SPL}.md5" ]; then
                        BYTES=$(wc -c "${UBOOT_SPL}" | cut -d ' ' -f 1)
                        EXPECTED=$(cut -f 1 -d ' ' "${UBOOT_SPL}.md5")
			# This looks annoyingly convoluted because it is.
			# In order to not get bogged down by reading very slowly
			# we read a large chunk, jump to where we need to start
			# then read the exact byte count. So we arn't using a bs
			# of 1 on the whole disk. It could probably be optimized
			# but it works.
                        ACTUAL=$(dd if="/dev/${UBOOT_DN}" bs=4M | \
                          dd skip="${UBOOT_SPL_OFFS}" bs=512 | \
			  dd bs=1 count="${BYTES}" | \
			  md5sum | \
                          cut -f 1 -d ' ')
                        if [ "${ACTUAL}" != "${EXPECTED}" ]; then
				crit_exit "U-Boot SPL verify"
                        fi
		fi
	) > /tmp/logs/u-boot-writeimage 2>&1
}
