#!/bin/sh

# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2021-2022 Technologic Systems, Inc. dba embeddedTS

# Edit these variables as needed. When porting, this should be all that
# needs to change for a new platform. Should be.

# Whole device node path for eMMC. Assuming it is static each boot.
EMMC_DEV="/dev/mmcblk1"

# Whole device node path for SD. Assuming it is static each boot.
SD_DEV="/dev/mmcblk0"

# The TS-7670 has two SD cards, whole path for second SD card
SD1_DEV="/dev/mmcblk2"

# Create array of valid file names for each media type
sdimage_tar="sdimage.tar.xz sdimage.tar.bz2 sdimage.tar.gz sdimage.tar"
sdimage_img="sdimage.dd.xz sdimage.dd.bz2 sdimage.dd.gz sdimage.dd"
sdimage="${sdimage_tar} ${sdimage_img}"
sd1image_tar="sd1image.tar.xz sd1image.tar.bz2 sd1image.tar.gz sd1image.tar"
sd1image_img="sd1image.dd.xz sd1image.dd.bz2 sd1image.dd.gz sd1image.dd"
sd1image="${sd1image_tar} ${sd1image_img}"
emmcimage_tar="emmcimage.tar.xz emmcimage.tar.bz2 emmcimage.tar.gz emmcimage.tar"
emmcimage_img="emmcimage.dd.xz emmcimage.dd.bz2 emmcimage.dd.gz emmcimage.dd"
emmcimage="${emmcimage_tar} ${emmcimage_img}"

# A space separated list of all potential accepted image names
all_images="${sdimage} ${sd1image} ${emmcimage}"

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


### Check for and handle second SD card images
# Order of search preferences handled by sd1image variable
(
	DID_SOMETHING=0
	for NAME in ${sd1image_tar}; do
		if [ -e "/mnt/usb/${NAME}" ]; then
			untar_image "/mnt/usb/${NAME}" "${SD1_DEV}" "sd1" "ext4compat"
			DID_SOMETHING=1
			break
		fi
	done

	if [ ${DID_SOMETHING} -ne 1 ]; then
		for NAME in ${sd1image_img}; do
			if [ -e "/mnt/usb/${NAME}" ]; then
				dd_image "/mnt/usb/${NAME}" "${SD1_DEV}" "sd1"
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
		capture_img_or_tar_from_disk "${SD_DEV}" "/mnt/usb" "sd" 2
	fi

	if [ -b "${SD1_DEV}" ] && \
	   [ -z "${IR_NO_CAPTURE_SD1}" ] && \
	   [ ! -e /tmp/failed ]; then
		capture_img_or_tar_from_disk "${SD1_DEV}" "/mnt/usb" "sd1" 2
	fi

	if [ -b "${EMMC_DEV}" ] && \
	   [ -z "${IR_NO_CAPTURE_EMMC}" ] && \
	   [ ! -e /tmp/failed ]; then
		capture_img_or_tar_from_disk "${EMMC_DEV}" "/mnt/usb" "emmc" 2
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
	# the image capture process.
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
		echo "One or more operations failed! $(cat /tmp/failed)"
		echo "Check /tmp/logs for more information."
	else
		echo "All operations succeeded!"
	fi
}
