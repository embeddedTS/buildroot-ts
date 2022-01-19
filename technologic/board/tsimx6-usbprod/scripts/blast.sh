#!/bin/sh

# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2021-2022 Technologic Systems, Inc. dba embeddedTS

# Edit these variables as needed. When porting, this should be all that
# needs to change for a new platform. Should be.

# Whole device device node path for eMMC. Assuming it is static each boot.
EMMC_DEV="/dev/mmcblk2"
# Partition prefix letter(s) for device node.
# e.g. /dev/mmcblk0p1, part prefix is "p". /dev/sda1, part prefix is ""
EMMC_PART_PREFIX="p"

# Whole device device node path for SD. Assuming it is static each boot.
SD_DEV="/dev/mmcblk1"
# Partition prefix letter(s) for device node.
# e.g. /dev/mmcblk0p1, part prefix is "p". /dev/sda1, part prefix is ""
SD_PART_PREFIX="p"

# Whole device device node path for SATA. Assuming it is static each boot.
SATA_DEV="/dev/sda"
# Partition prefix letter(s) for device node.
# e.g. /dev/mmcblk0p1, part prefix is "p". /dev/sda1, part prefix is ""
SATA_PART_PREFIX=""

UBOOT_DEV="/dev/mtdblock0"


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

# A space separated list of all potential accepted image names
all_images="${sdimage} ${emmcimage} ${sataimage} ${uboot_img}"

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
			untar_image "/mnt/usb/${NAME}" "${SD_DEV}" "${SD_PART_PREFIX}" "sd" "ext4compat"
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
			untar_image "/mnt/usb/${NAME}" "${EMMC_DEV}" "${EMMC_PART_PREFIX}" "emmc" "ext4compat"
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
			untar_image "/mnt/usb/${NAME}" "${SATA_DEV}" "${SATA_PART_PREFIX}" "sata"
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

### U-Boot is unique to every platform and therefore the full process for it
###   needs to be replicated and customized to each platform. Some parts of the
###   following may be more re-usable than others
if [ -e "/mnt/usb/${uboot_img}" ]; then
	echo "========== Writing new U-boot image =========="
	(
		set -x

		eval "$(dd if=${UBOOT_DEV} bs=1024 skip=1 count=512 2>/dev/null | strings | grep imx_type)"
		if [ -z "${imx_type}" ]; then err_exit "Unable to detect imx_type in flash!"; fi
		BOARD_IMX_TYPE="${imx_type}"


		eval "$(strings /mnt/usb/${uboot_img} | grep imx_type)"
		if [ -z "${imx_type}" ]; then err_exit "Unable to detect imx_type in image file!"; fi
		IMAGE_IMX_TYPE="${imx_type}"

		if [ "$BOARD_IMX_TYPE" != "$IMAGE_IMX_TYPE" ]; then
			err_exit "IMX_TYPE $BOARD_IMX_TYPE and $IMAGE_IMX_TYPE didn't match. Writing this may brick the device or cause instability. Refusing to write U-Boot!"
		else
			dd if=/mnt/usb/"${uboot_img}" of="${UBOOT_DEV}" bs=1024 seek=1 conv=fsync || err_exit "U-Boot write failed"
			if [ -e /mnt/usb/"${uboot_img}".md5 ]; then
				sync
				# Flush any buffer cache
				echo 3 > /proc/sys/vm/drop_caches

				BYTES=$(wc -c /mnt/usb/"${uboot_img}" | cut -d ' ' -f 1)
				EXPECTED=$(cut -f 1 -d ' ' /mnt/usb/"${uboot_img}".md5)

				# Read back from spi flash
				TMPFILE=$(mktemp)

				# Realistically, using a bs of 1 does not have
				# a huge impact on time to read
				dd if="${UBOOT_DEV}" bs=1 skip=1024 count="${BYTES}" of="${TMPFILE}"
				UBOOT_FLASH=$(md5sum "${TMPFILE}" | cut -f 1 -d ' ')

				if [ "$UBOOT_FLASH" != "$EXPECTED" ]; then
					err_exit "U-Boot verify failed"
				fi
			fi
		fi

	) > /tmp/logs/u-boot-writeimage 2>&1 &
fi


}

# This is our automatic capture of disk images
capture_images() {
	if [ -b "${SD_DEV}" ]; then
        	capture_img_or_tar_from_disk "${SD_DEV}" "/mnt/usb" "sd"
	fi

	if [ -b "${EMMC_DEV}" ]; then
        	capture_img_or_tar_from_disk "${EMMC_DEV}" "/mnt/usb" "emmc"
	fi

	# Only capture an image from SATA if SATA_DEV is a SATA device
	# and the device node is a block device.
        readlink /sys/class/block/"$(basename ${SATA_DEV})" | grep sata >/dev/null
	if [ $? -eq 0 ] && [ -b "${SATA_DEV}" ]; then
        	capture_img_or_tar_from_disk "${SATA_DEV}" "/mnt/usb" "sata"
	fi
}

blast_run() {
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
		echo "One or more images failed! $(cat /tmp/failed)"
		echo "Check /tmp/logs for more information."
	else
		echo "All images wrote correctly!"
	fi
}
