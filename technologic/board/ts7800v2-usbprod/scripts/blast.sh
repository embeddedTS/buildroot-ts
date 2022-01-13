#!/bin/sh

# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2021-2022 Technologic Systems, Inc. dba embeddedTS

# Edit these variables as needed. When porting, this should be all that
# needs to change for a new platform. Should be.

# Whole device device node path for eMMC. Assuming it is static each boot.
EMMC_DEV="/dev/mmcblk0"
# Partition prefix letter(s) for device node.
# e.g. /dev/mmcblk0p1, part prefix is "p". /dev/sda1, part prefix is ""
EMMC_PART_PREFIX="p"

# Whole device device node path for SD. Assuming it is static each boot.
SD_DEV="/dev/tssdcarda"
# Partition prefix letter(s) for device node.
# e.g. /dev/mmcblk0p1, part prefix is "p". /dev/sda1, part prefix is ""
SD_PART_PREFIX=""

# Whole device device node path for SATA. Assuming it is static each boot.
SATA_DEV="/dev/sda"
# Partition prefix letter(s) for device node.
# e.g. /dev/mmcblk0p1, part prefix is "p". /dev/sda1, part prefix is ""
SATA_PART_PREFIX=""

# U-Boot is stored on boot partitions of eMMC on platforms compatible with
# this script.
UBOOT_DEV="${EMMC_DEV}boot0"
# The basename of the partition is needed as part of the update process in
# order to unlock the boot partition for writing.
UBOOT_BN=$(basename "${UBOOT_DEV}")


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
uboot_img="u-boot.kwb"

# NOTE! These file names need to be symlinks to the actual, original filenames
# as downloaded from FTP. The reason is due to the original names containing the
# revision number in the name which the script needs to see if the FPGA should be
# updated. But, in such a way that can be solidly matched without fuzz from
# wildcards. e.g. we could match ts7800v2_fpga*.rpd, but that could match
# multiple files if multiple are copied to the disk in error. Requiring a symlink
# helps reduce foot injuries.
#
# e.g.
# ln -sf ts7800v2_fpga_rev44.rpd ts7800v2-fpga.rpd
# ln -sf ts7800v2_fpga_rev47_updater ts7800v2-fpga-updater
fpga_img="ts7800v2-fpga.rpd"
fpga_update="ts7800v2-fpga-updater"
fpga="${fpga_update} ${fpga_img}"

# A space separated list of all potential accepted image names
all_images="${sdimage} ${emmcimage} ${sataimage} ${uboot_img} ${fpga}"

# Functions to turn LEDs on and off easily
redled_on() { ts7800ctl -n ; }
redled_off() { ts7800ctl -F ; }
grnled_on() { ts7800ctl -g ; }
grnled_off() { ts7800ctl -G ; }


# Once the device nodes/partitions and valid image names are established,
# then source in the functions that handle the writing processes
. /mnt/usb/blast_funcs.sh

mkdir /tmp/logs

redled_on
grnled_off



# Our default automatic use of the blast functions
# Rather than calling this function, the calls made here can be integrated
# in to custom blast processes
write_images() {

	### Write FPGA bitstream from file or actual update utility
	# NOTE!
	# The filenames ${fpga_img} and/or ${fpga_update} MUST be symlinks to
	# the actual file and CANNOT be renamed!
	#
	# NOTE!
	# This needs to be run before attempting any other write process since it
	# causes the FPGA to go braindead and requires a hardware reset before any
	# FPGA peripherals can function again. Additionally, all messages go to
	# console for this segment
	if [ -e "/mnt/usb/${fpga_img}" ] || [ -e "/mnt/usb/${fpga_update}" ]; then

		# FPGA binary is in SPI flash
		modprobe m25p80

		if [ -e "/mnt/usb/${fpga_update}" ]; then
			echo "========== Writing new FPGA bitstream via updater =========="
			(
				set -x

				FPGAFILE=$(readlink /mnt/usb/"${fpga_update}") || err_exit "File /mnt/usb/${fpga_update} must be a symlink"
				NEWREV=${FPGAFILE%_updater}
				NEWREV=$(echo "${NEWREV}" | sed -e 's/^.*rev//')
				if [ -z "${NEWREV}" ]; then
					err_exit "Invalid revision string in file /mnt/usb/${FPGAFILE}"
				fi

				eval "$(ts7800ctl -i)" || err_exit "ts7800ctl failed"
				# ts7800ctl prints in hex
				if [ -z "${fpga_rev}" ]; then err_exit "Unknown FPGA rev"; fi
				FPGAREV=$((fpga_rev))

				if [ ${FPGAREV} -lt ${NEWREV} ]; then
					/mnt/usb/"${FPGAFILE}" || err_exit "Failed to program FPGA"
					reboot -f
				else
					echo "FPGA is newer or same as updater, not updating!"
				fi

			)

		elif [ -e "/mnt/usb/${fpga_img}" ]; then
			echo "========== Writing new FPGA bitstream from file =========="
			(
				set -x

				FPGAFILE=$(readlink /mnt/usb/"${fpga_img}") || err_exit "File ${fpga_img} must be a symlink"
				NEWREV=${FPGAFILE%.rpd}
				NEWREV=$(echo "${NEWREV}" | sed -e 's/^.*rev//')
				if [ -z "${NEWREV}" ]; then
					err_exit "Invalid revision string in file /mnt/usb/${FPGAFILE}"
				fi

				eval "$(ts7800ctl -i)" || err_exit "ts7800ctl failed"
				# ts7800ctl prints in hex
				if [ -z "${fpga_rev}" ]; then err_exit "Unknown FPGA rev"; fi
				# ts7800ctl prints in hex
				FPGAREV=$((fpga_rev))

				if [ ${FPGAREV} -lt ${NEWREV} ]; then
					load_fpga_flash /mnt/usb/"${fpga_img}" || err_exit "Failed to program FPGA"
					reboot -f
				else
					echo "FPGA is newer or same as image, not updating!"
				fi
			)
		fi
	fi

### Check for and handle SD images
# Order of search preferences handled by sdimage variable
(
	DID_SOMETHING=0
	for NAME in ${sdimage_tar}; do
		if [ -e "/mnt/usb/${NAME}" ]; then
			untar_image "/mnt/usb/${NAME}" "${SD_DEV}" "${SD_PART_PREFIX}" "sd" "ext4"
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
			untar_image "/mnt/usb/${NAME}" "${EMMC_DEV}" "${EMMC_PART_PREFIX}" "emmc" "ext4"
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

		echo 0 > /sys/block/"${UBOOT_BN}"/force_ro
		dd bs=1024 if=/mnt/usb/"${uboot_img}" of="${UBOOT_DEV}" conv=fsync,notrunc
		if [ -e "/mnt/usb/${uboot_img}.md5" ]; then
			BYTES=$(wc -c /mnt/usb/"${uboot_img}" | cut -d ' ' -f 1)
			EXPECTED=$(cut -f 1 -d ' ' /mnt/usb/"${uboot_img}".md5)
			ACTUAL=$(dd if="${UBOOT_DEV}" bs=4M | head -c "${BYTES}" | md5sum | cut -f 1 -d ' ')
			if [ "${ACTUAL}" != "${EXPECTED}" ]; then
				echo "U-Boot dd verify" >> /tmp/failed
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

# Check for any one of the valid image sources, if none exist, then start
# the image capture process. Note that, if uboot_img or fpga_* exist, then no
# images are captured. If they do not exist, neither are captured as this
# is something that is not really standard and not something to replicate
# between units and should rather be from official source binaries
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



(
set +x
# Blink green led if it works.  Blink red if bad things happened
if [ ! -e /tmp/failed ]; then
	redled_off
	echo "All images wrote correctly!"
	while true; do
		sleep 1
		grnled_on
		sleep 1
		grnled_off
	done
else
	grnled_off
	echo "One or more images failed! $(cat /tmp/failed)"
	echo "Check /tmp/logs for more information."
	while true; do
		sleep 1
		redled_on
		sleep 1
		redled_off
	done
fi
) &
