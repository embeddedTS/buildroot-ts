#!/bin/sh

# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2021-2022 Technologic Systems, Inc. dba embeddedTS

# Edit these variables as needed. When porting, this should be all that
# needs to change for a new platform. Should be.

# Whole device node path for eMMC. Assuming it is static each boot.
EMMC_DEV="/dev/mmcblk1"

# Whole device node path for SD. Assuming it is static each boot.
SD_DEV="/dev/mmcblk0"

# U-Boot is stored on boot partitions of eMMC on platforms compatible with
# this script.
UBOOT_DEV="${EMMC_DEV}boot0"
# The basename of the partition is needed as part of the update process in
# order to unlock the boot partition for writing.
UBOOT_BN=$(basename "${UBOOT_DEV}")


# Create array of valid file names for each media type
sdimage_tar="sdimage.tar.xz sdimage.tar.bz2 sdimage.tar.gz sdimage.tar"
sdimage_img="sdimage.dd.xz sdimage.dd.bz2 sdimage.dd.gz sdimage.dd"
sdimage="${sdimage_tar} ${sdimage_img}"
emmcimage_tar="emmcimage.tar.xz emmcimage.tar.bz2 emmcimage.tar.gz emmcimage.tar"
emmcimage_img="emmcimage.dd.xz emmcimage.dd.bz2 emmcimage.dd.gz emmcimage.dd"
emmcimage="${emmcimage_tar} ${emmcimage_img}"
uboot_img="u-boot.imx"

# A space separated list of all potential accepted image names
all_images="${sdimage} ${emmcimage} ${uboot_img}"

# Set up LED definitions, this needs to happen before blast_funcs.sh is sourced
led_init() {
	grnled_on() { echo 1 > /sys/class/leds/green-led/brightness ; }
	grnled_off() { echo 0 > /sys/class/leds/green-led/brightness ; }
	redled_on() { echo 1 > /sys/class/leds/red-led/brightness ; }
	redled_off() { echo 0 > /sys/class/leds/red-led/brightness ; }

	led_blinkloop
}


# Once the device nodes/partitions and valid image names are established,
# then source in the functions that handle the writing processes
# shellcheck disable=SC1091
. /mnt/usb/blast_funcs.sh

mkdir /tmp/logs

# Our default automatic use of the blast functions
# Rather than calling this function, the calls made here can be integrated
# in to custom blast processes
write_images() {

### Write U-Boot first, if applicable. Bail if it fails for any reason
if [ -e "/mnt/usb/${uboot_img}" ]; then
	(

	# shellcheck disable=SC3040
	set -o pipefail

	# First, check if we are on a TS-4100. If so, there are some rudimentary
	# checks we can do to ensure that the correct U-Boot binary is going to
	# be loaded
	grep "TS-4100" /proc/device-tree/model >/dev/null 2>/dev/null
	RET="${?}"
	if [ "${RET}" -eq 0 ]; then
		# Next, get the imx_type that U-Boot exported. Note that this
		# does depend on U-Boot already being correct for this platform!
		CMDLINE=$(cat /proc/cmdline)
		for I in ${CMDLINE}; do
			case $I in
				imx_type=*)
					BOARD_IMX_TYPE="${I#imx_type=}"
					;;
			esac
		done
		unset imx_type

		# Now, get the imx_type exported by the U-Boot binary
		eval "$(strings /mnt/usb/${uboot_img} | grep imx_type |head -n1)"
		if [ -z "${imx_type}" ]; then
			err_exit "imx_type not found in U-Boot update binary!"
		fi
		if [ "${BOARD_IMX_TYPE}" != "${imx_type}" ]; then
			err_exit "System type ${BOARD_IMX_TYPE} and U-Boot update binary type ${imx_type} differ, refusing to write the update binary!"
		fi
	fi
	)

	if [ ! -e "/tmp/failed" ]; then
		write_uboot "${UBOOT_BN}" "/mnt/usb/${uboot_img}" 2
	fi

	# If that failed, abort writing anything else
	if [ -e "/tmp/failed" ]; then
		return
	fi
fi

### Check for and handle SD images
# Order of search preferences handled by sdimage variable
(
	DID_SOMETHING=0
	for NAME in ${sdimage_tar}; do
		if [ -e "/mnt/usb/${NAME}" ]; then
			untar_image "/mnt/usb/${NAME}" "${SD_DEV}" "sd" "ext4compat"
			DID_SOMETHING=1
			break
		fi
	done

	if [ ${DID_SOMETHING} -ne 1 ]; then
		for NAME in ${sdimage_img}; do
			if [ -e "/mnt/usb/${NAME}" ]; then
				dd_image "/mnt/usb/${NAME}" "${SD_DEV}" "sd"
				break
			fi
		done
	fi

	wait
) &

### Check for and handle eMMC images
# Order of search preferences handled by emmcimage variable
(
	DID_SOMETHING=0
	for NAME in ${emmcimage_tar}; do
		if [ -e "/mnt/usb/${NAME}" ]; then
			untar_image "/mnt/usb/${NAME}" "${EMMC_DEV}" "emmc" "ext4compat"
			DID_SOMETHING=1
			break
		fi
	done

	if [ ${DID_SOMETHING} -ne 1 ]; then
		for NAME in ${emmcimage_img}; do
			if [ -e "/mnt/usb/${NAME}" ]; then
				dd_image "/mnt/usb/${NAME}" "${EMMC_DEV}" "emmc"
				break
			fi
		done
	fi

	wait
) &
}

# This is our automatic capture of disk images
capture_images() {
	if [ -b "${SD_DEV}" ] && \
	   [ -z "${IR_NO_CAPTURE_SD}" ]; then
		capture_img_or_tar_from_disk "${SD_DEV}" "/mnt/usb" "sd"
	fi

	if [ -b "${EMMC_DEV}" ] && \
	   [ -z "${IR_NO_CAPTURE_EMMC}" ] && \
	   [ ! -e /tmp/failed ]; then
		capture_img_or_tar_from_disk "${EMMC_DEV}" "/mnt/usb" "emmc"
	fi
}


blast_run() {
	# Get all options that may be set
	get_env_options "/mnt/usb/"

	# Check to see if the user wanted to only drop to a shell
	if [ -n "${IR_SHELL_ONLY}" ]; then
		echo "NOT running production process, dropping to shell!"
		# Set a failed condition to not cause confusion that the process
		# successfully completed.
		touch /tmp/failed
		touch /tmp/completed

		exit
	fi

	# Check for any one of the valid image sources, if none exist, then start
	# the image capture process. Note that, if uboot_img exists, then no images
	# are captured. If it does not exist, the uboot_img is not captured as this
	# is something that is not really standard
	USB_HAS_VALID_IMAGES=0
	for NAME in ${all_images}; do
		if [ -e "/mnt/usb/${NAME}" ]; then
			USB_HAS_VALID_IMAGES=1
		fi
	done

	if [ ${USB_HAS_VALID_IMAGES} -eq 0 ]; then
		# Need to remount our base dir RW
		mount -oremount,rw /mnt/usb
		capture_images
		mount -oremount,ro /mnt/usb
	else
		write_images
	fi


	# Wait for all processes to complete
	wait

	# Touch /tmp/completed to tell the LED blinking loop to indicate done
	touch /tmp/completed

	# If anything failed at this point, be noisy on console about it
	if [ -e /tmp/failed ] ;then
		echo ""
		echo "One or more operations failed!"
		echo "=================================================="
		cat /tmp/failed
		echo "=================================================="
		echo "Check /tmp/logs for more information."
	else
		echo "All operations succeeded!"
	fi
}
