#!/bin/sh

# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2022 Technologic Systems, Inc. dba embeddedTS

# Edit these variables as needed. When porting, this should be all that
# needs to change for a new platform. Should be.

# XXX: See if its possible to easily detect a 7800v2 and enable SD for this

# Whole device node path for eMMC. Assuming it is static each boot.
EMMC_DEV="/dev/mmcblk0"

# Whole device node path for SATA. Assuming it is static each boot.
SATA_DEV="/dev/sda"

# U-Boot is stored on boot partitions of eMMC on platforms compatible with
# this script.
UBOOT_DEV="${EMMC_DEV}boot0"
# The basename of the partition is needed as part of the update process in
# order to unlock the boot partition for writing.
UBOOT_BN=$(basename "${UBOOT_DEV}")


# Create array of valid file names for each media type
emmcimage_tar="emmcimage.tar.xz emmcimage.tar.bz2 emmcimage.tar.gz emmcimage.tar"
emmcimage_img="emmcimage.dd.xz emmcimage.dd.bz2 emmcimage.dd.gz emmcimage.dd"
emmcimage="${emmcimage_tar} ${emmcimage_img}"
sataimage_tar="sataimage.tar.xz sataimage.tar.bz2 sataimage.tar.gz sataimage.tar"
sataimage_img="sataimage.dd.xz sataimage.dd.bz2 sataimage.dd.gz sataimage.dd"
sataimage="${sataimage_tar} ${sataimage_img}"
uboot_img="u-boot-spl.kwb"

# A space separated list of all potential accepted image names
all_images="${emmcimage} ${sataimage} ${uboot_img}"

# Set up LED definitions, this needs to happen before blast_funcs.sh is sourced
led_init() {
	grnled_on() { echo 1 > "/sys/class/leds/green:power/brightness" ; }
	grnled_off() { echo 0 > "/sys/class/leds/green:power/brightness" ; }
	redled_on() { echo 1 > "/sys/class/leds/red:status/brightness" ; }
	redled_off() { echo 0 > "/sys/class/leds/red:status/brightness" ; }

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
        write_uboot "${UBOOT_BN}" \
                    "/mnt/usb/${uboot_img}" 0

        # If that failed, abort writing anything else
        if [ -e "/tmp/failed" ]; then
                return
        fi
fi

### Check for and handle eMMC images
# Order of search preferences handled by emmcimage variable
(
	DID_SOMETHING=0
	for NAME in ${emmcimage_tar}; do
		if [ -e "/mnt/usb/${NAME}" ]; then
			untar_image "/mnt/usb/${NAME}" "${EMMC_DEV}" "emmc" "ext4gpt"
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

	readlink /sys/class/block/"$(basename ${SATA_DEV})" | grep sata >/dev/null || err_exit "SATA disk not found!"

	DID_SOMETHING=0
	for NAME in ${sataimage_tar}; do
		if [ -e "/mnt/usb/${NAME}" ]; then
			untar_image "/mnt/usb/${NAME}" "${SATA_DEV}" "sata" "ext4gpt"
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
	if [ -b "${EMMC_DEV}" ] && \
	   [ -z "${IR_NO_CAPTURE_EMMC}" ]; then
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
	# the image capture process. Note that, if uboot_img or fpga_* exist, then
	# no images are captured. If they do not exist, neither are captured as
	# this is something that is not really standard and not something to
	# replicate between units and should rather be from official source
	# binaries
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
		echo "One or more images failed! $(cat /tmp/failed)"
		echo "Check /tmp/logs for more information."
	else
		echo "All images wrote correctly!"
	fi
}
