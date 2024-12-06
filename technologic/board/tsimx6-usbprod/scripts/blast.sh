#!/bin/sh

# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2021-2022 Technologic Systems, Inc. dba embeddedTS

# Edit these variables as needed. When porting, this should be all that
# needs to change for a new platform. Should be.

# Whole device node path for eMMC. Assuming it is static each boot.
EMMC_DEV="/dev/mmcblk2"

# Whole device node path for SD. Assuming it is static each boot.
SD_DEV="/dev/mmcblk1"

# Whole device node path for SATA. Assuming it is static each boot.
SATA_DEV="/dev/sda"

UBOOT_DEV="mtdblock0"


# Create array of valid file names for each media type
sdimage_tar="sdimage.tar.xz sdimage.tar.bz2 sdimage.tar.gz sdimage.tar"
sdimage_img="adimage.dd.xz sdimage.dd.bz2 sdimage.dd.gz sdimage.dd"
sdimage="${sdimage_tar} ${sdimage_img}"
emmcimage_tar="emmcimage.tar.xz emmcimage.tar.bz2 emmcimage.tar.gz emmcimage.tar"
emmcimage_img="emmcimage.dd.xz emmcimage.dd.bz2 emmcimage.dd.gz emmcimage.dd"
emmcimage="${emmcimage_tar} ${emmcimage_img}"
sataimage_tar="sataimage.tar.xz sataimage.tar.bz2 sataimage.tar.gz sataimage.tar"
sataimage_img="sataimage.dd.xz sataimage.dd.bz2 sataimage.dd.gz sataimage.dd"
sataimage="${sataimage_tar} ${sataimage_img}"
uboot_img="u-boot.imx"
micro_bin="micro-update.bin"

# A space separated list of all potential accepted image names
all_images="${sdimage} ${emmcimage} ${sataimage} ${uboot_img} ${micro_bin}"

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

write_microcontroller() {
### Check for an handle microcontroller updates.
# This runs first since this may reboot if there is an update
if [ -e "/mnt/usb/${micro_bin}" ]; then
	wizard_update "/mnt/usb/${micro_bin}"
fi
}


# Our default automatic use of the blast functions
# Rather than calling this function, the calls made here can be integrated
# in to custom blast processes
write_images() {

if [ -e "/mnt/usb/${uboot_img}" ]; then
	(
	# shellcheck disable=SC3040
	set -o pipefail

	# Get imx_type as exported by U-Boot
	# This is the best way to get it reliably since it has been
	# observed that different versions of U-Boot store the variables
	# differently in the environment
	CMDLINE=$(cat /proc/cmdline)
	for I in ${CMDLINE}; do
		case $I in
			imx_type=*)
				BOARD_IMX_TYPE="${I#imx_type=}"
				;;
		esac
	done

	# Get imx_type from the new image
	# Older binaries seem to not have '=' used as a separator, but
	# have EITHER <val>\0<var> or <var>\0<val> in memory; I've not found
	# a specific reason for one or the other. Below, first check for '=' as
	# a separator, then <val>\0<var>, if <val> at that point does not start
	# with 'ts' then the model number, then use <var>\0<val>.
	# Note that, this is not a 100% perfect check and it may still cause
	# issues in a situation with a custom U-Boot binary depending on where
	# variable names and values fall in memory. This is however, confirmed
	# to work with all of our stock U-Boot binary builds.
	unset imx_type
	eval "$(strings /mnt/usb/${uboot_img} | grep imx_type |head -n1)" 2>/dev/null
	if [ -z "${imx_type}" ]; then
		# Attempt to extract imx_type from older binary
		imx_type="$(strings /mnt/usb/${uboot_img} | grep -B1 imx_type | \
			head -n1)"
		# Check if ${imx_type} starts with 'ts' and 4 digit model, if
		# not, then its not likely to correctly be imx_type and instead
		# get the imx_type from the string after the variable name.
		case "${imx_type}" in
			ts4900*|ts7970*|ts7990*)
				;;
			*)
				imx_type="$(strings /mnt/usb/${uboot_img} | \
					grep -A1 imx_type | tail -n1)"
				;;
		esac
	fi

	if [ "${BOARD_IMX_TYPE}" != "${imx_type}" ]; then
		err_exit "System type ${BOARD_IMX_TYPE} and U-Boot update binary type ${imx_type} differ, refusing to write the update binary!"
	fi
	)

	if [ ! -e "/tmp/failed" ]; then
		write_uboot "${UBOOT_DEV}" "/mnt/usb/${uboot_img}" 2
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

### Check for and handle SATA images
# Order of search preferences handled by emmcimage variable
(
	# Check to see that the SATA device is actually sata!
        # It should be, but if there is any issue
        # with the drive it may not be recognized and then SATA_DEV could end
	# up pointing to USB. But first, check to see if any SATA images
	# are present on disk to prevent extraneous output
	SATA_IMAGES=0
	for NAME in ${sataimage}; do
		if [ -e "/mnt/usb/${NAME}" ]; then SATA_IMAGES=1; fi
	done

	if [ ${SATA_IMAGES} -eq 0 ]; then exit; fi

        readlink /sys/class/block/"$(basename ${SATA_DEV})" | grep sata >/dev/null \
		|| err_exit "SATA disk not found!"

	DID_SOMETHING=0
	for NAME in ${sataimage_tar}; do
		if [ -e "/mnt/usb/${NAME}" ]; then
			untar_image "/mnt/usb/${NAME}" "${SATA_DEV}" "sata"
			DID_SOMETHING=1
			break
		fi
	done

	if [ ${DID_SOMETHING} -ne 1 ]; then
		for NAME in ${sataimage_img}; do
			if [ -e "/mnt/usb/${NAME}" ]; then
				dd_image "/mnt/usb/${NAME}" "${SATA_DEV}" "sata"
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

	# Only capture an image from SATA if SATA_DEV is a SATA device
	# and the device node is a block device.
	readlink /sys/class/block/"$(basename ${SATA_DEV})" | grep sata >/dev/null
	RET=${?}
	if [ "${RET}" -eq 0 ] && \
	   [ -b "${SATA_DEV}" ] && \
	   [ -z "${IR_NO_CAPTURE_SATA}" ] && \
	   [ ! -e /tmp/failed ]; then
		capture_img_or_tar_from_disk "${SATA_DEV}" "/mnt/usb" "sata"
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
		# Attempt to update supervisory microcontroller first
		# since it may reboot upon success
		write_microcontroller
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
