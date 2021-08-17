#!/bin/bash

set -o pipefail

mkdir /mnt/emmc
mkdir /mnt/sata
mkdir /tmp/logs

SATA_PRESENT="0"
SATA_DEV=$(readlink -f /dev/disk/by-path/platform-f10a8000.sata-ata-1)
if [ -b "$SATA_DEV" ]; then
	SATA_PRESENT="1"
fi
export SATA_PRESENT SATA_DEV

# Turn on red LED to indicate that its processing.
echo 1 > /sys/class/leds/right-red-led/brightness
echo 0 > /sys/class/leds/right-green-led/brightness

if [ -e "/mnt/usb/emmcimage.dd.xz" ]; then
	echo "======= Writing eMMC card image ========"
	(
		xzcat /mnt/usb/emmcimage.dd.xz | dd of=/dev/mmcblk0 bs=1M
		if [ $? -ne 0 ]; then
			echo "Failed to write disk image" >> /tmp/failed
			exit 1
		fi

		# Flush any buffer cache
		echo 3 > /proc/sys/vm/drop_caches

		LEN=$(xz --list --robot /mnt/usb/emmcimage.dd.xz | tail -1 | cut -f 5)
		x=$((LEN & 0xFFFF))
		if [ "$x" -ne 0 ]; then
			echo "Image not aligned to 64kbyte" >> /tmp/failed
			exit 1
		fi
		LEN=$((LEN / 65536))

		echo "=== Verifying md5sum  from eMMC ==="
		EXPECTED_MD5=$(cat /mnt/usb/emmcimage.dd.md5 | cut -d ' ' -f 1)
		if [ $? -ne 0 ]; then
			echo "emmcimage.dd.md5 file not found" >> /tmp/failed
			exit 1
		fi

		EMMC_MD5=$(dd if=/dev/mmcblk0 bs=65536 count=${LEN} | md5sum - | cut -d ' ' -f 1)
		if [ $? -ne 0 ]; then
			echo "Failed to read MD5 from disk" >> /tmp/failed
			exit 1
		fi

		if [ "${EXPECTED_MD5}" != "${EMMC_MD5}" ]; then
			echo "MD5 of disk did not match expected" >> /tmp/failed
			exit 1
		fi

	) > /tmp/logs/emmc-writefs 2>&1 &
fi

if [ -e "/mnt/usb/emmcimage.tar.xz" ]; then
	echo "======= Writing eMMC card filesystem ========"
	(
		sgdisk --zap-all /dev/mmcblk0
		# Create one single GPT linux partition
		if ! sgdisk -n 0:0:0 -t 0:8300 /dev/mmcblk0; then
			echo "emmc sgdisk new partition failed" >> /tmp/failed
			exit 1
		fi

		if ! mkfs.ext4 /dev/mmcblk0p1 -q < /dev/null; then
			echo "emmc sgdisk new partition failed" >> /tmp/failed
			exit 1
		fi

		if ! mount /dev/mmcblk0p1 /mnt/emmc; then
			echo "emmc mount failed" >> /tmp/failed
			exit 1
		fi

		if ! tar --numeric-owner -xf /mnt/usb/emmcimage.tar.xz -C /mnt/emmc/; then
			echo "emmc filesystem write failed" >> /tmp/failed
			exit 1
		fi

		if [ -e "/mnt/emmc/md5sums.txt" ]; then
			LINES=$(wc -l /mnt/emmc/md5sums.txt  | cut -f 1 -d ' ')
			if [ $LINES = 0 ]; then
				echo "==========MD5sum file blank==========="
				echo "mmcblk0 md5sum file is blank" >> /tmp/failed
				exit 1
			fi
			# Drop caches so we have to reread all files
			echo 3 > /proc/sys/vm/drop_caches
			cd /mnt/emmc/
			md5sum -c md5sums.txt > /tmp/emmc_md5sums
			if [ $? != 0 ]; then
				echo "mmcblk0 filesystem verify" >> /tmp/failed
				exit 1
			fi
			cd /
		fi

		if ! umount /mnt/emmc; then
			echo "Failed to unmount" >> /tmp/failed
			exit 1
		fi

	) > /tmp/logs/emmc-writefs 2>&1 &
fi

if [ "$SATA_PRESENT" == "1" ]; then
	if [ -e "/mnt/usb/sataimage.dd.xz" ]; then
	echo "======= Writing sata card image ========"
	(
		xzcat /mnt/usb/sataimage.dd.xz | dd of=${SATA_DEV} bs=1M
		if [ $? -ne 0 ]; then
			echo "Failed to write disk image" >> /tmp/failed
			exit 1
		fi

		# Flush any buffer cache
		echo 3 > /proc/sys/vm/drop_caches

		LEN=$(xz --list --robot /mnt/usb/sataimage.dd.xz | tail -1 | cut -f 5)
		x=$((LEN & 0xFFFF))
		if [ "$x" -ne 0 ]; then
			echo "Image not aligned to 64kbyte" >> /tmp/failed
			exit 1
		fi
		LEN=$((LEN / 65536))

		echo "=== Verifying md5sum  from sata ==="
		EXPECTED_MD5=$(cat /mnt/usb/sataimage.dd.md5 | cut -d ' ' -f 1)
		if [ $? -ne 0 ]; then
			echo "sataimage.dd.md5 file not found" >> /tmp/failed
			exit 1
		fi

		SATA_MD5=$(dd if=${SATA_DEV} bs=65536 count=${LEN} | md5sum - | cut -d ' ' -f 1)
		if [ $? -ne 0 ]; then
			echo "Failed to read MD5 from disk" >> /tmp/failed
			exit 1
		fi

		if [ "${EXPECTED_MD5}" != "${SATA_MD5}" ]; then
			echo "MD5 of disk did not match expected" >> /tmp/failed
			exit 1
		fi

	) > /tmp/logs/sata-writefs 2>&1 &
fi

if [ -e "/mnt/usb/sataimage.tar.xz" ]; then
	echo "======= Writing sata card filesystem ========"
	(
		sgdisk --zap-all "$SATA_DEV"
		# Create one single GPT linux partition
		if ! sgdisk -n 0:0:0 -t 0:8300 ${SATA_DEV}; then
			echo "sata sgdisk new partition failed"  >> /tmp/failed
			exit 1
		fi

		if ! mkfs.ext4 ${SATA_DEV}1 -q < /dev/null; then
			echo "sata sgdisk new partition failed"  >> /tmp/failed
			exit 1
		fi

		if ! mount ${SATA_DEV}1 /mnt/sata; then
			echo "sata mount failed"  >> /tmp/failed
			exit 1
		fi

		if ! tar --numeric-owner -xf /mnt/usb/sataimage.tar.xz -C /mnt/sata/; then
			echo "sata filesystem write failed"  >> /tmp/failed
			exit 1
		fi

		if [ -e "/mnt/sata/md5sums.txt" ]; then
			LINES=$(wc -l /mnt/sata/md5sums.txt  | cut -f 1 -d ' ')
			if [ $LINES = 0 ]; then
				echo "==========MD5sum file blank==========="
				echo "sata md5sum file is blank" >> /tmp/failed
				exit 1
			fi
			# Drop caches so we have to reread all files
			echo 3 > /proc/sys/vm/drop_caches
			cd /mnt/sata/
			md5sum -c md5sums.txt > /tmp/sata_md5sums
			if [ $? != 0 ]; then
				echo "sata filesystem verify" >> /tmp/failed
				exit 1
			fi
			cd /
		fi

		if ! umount /mnt/sata; then
			echo "Failed to unmount" >> /tmp/failed
			exit 1
		fi

	) > /tmp/logs/sata-writefs 2>&1 &
fi
fi

### U-boot ###
if [ -e "/mnt/usb/u-boot-spl.kwb" ]; then
	echo "============== Updating U-Boot =============="
	(
		# Unlock boot0 partition
		echo 0 > /sys/block/mmcblk0boot0/force_ro

		# Write U-Boot binary to boot0
		dd if=/mnt/usb/u-boot-spl.kwb of=/dev/mmcblk0boot0 conv=fsync
		if [ $? -ne 0 ]; then
			echo "Failed to write U-Boot to disk" >> /tmp/failed
		fi

		# Lock boot0 partition
		echo 1 > /sys/block/mmcblk0boot0/force_ro

		# Check MD5
		if [ -e /mnt/usb/u-boot-spl.kwb.md5 ]; then
			echo "===== Checking md5sum of U-Boot binary ====="
			# Flush any buffer cache
			echo 3 > /proc/sys/vm/drop_caches


			EXPECTED_MD5=$(cat /mnt/usb/u-boot-spl.kwb.md5 | cut -d ' ' -f 1)

			imgsize=$(stat -L -t /mnt/usb/u-boot-spl.kwb| cut -d ' ' -f 2)
			UBOOT_MD5=$(dd if=/dev/mmcblk0boot0 bs=1 count=${imgsize} | md5sum - | cut -d ' ' -f 1)
			if [ $? -ne 0 ]; then
				echo "Failed U-Boot md5sum readback" >> /tmp/failed
			fi

			if [ "${EXPECTED_MD5}" != "${UBOOT_MD5}" ]; then
				echo "MD5 of U-Boot read did not match expected" >> /tmp/failed
			fi
		fi
	) > /tmp/logs/spi-bootimg 2>&1 &
fi

sync
wait

(
# Blink green led if it works.  Blink red if bad things happened
if [ ! -e /tmp/failed ]; then
	echo 0 > /sys/class/leds/right-red-led/brightness
	echo "All images wrote correctly!"
	while true; do
		sleep 1
		echo 1 > /sys/class/leds/right-green-led/brightness
		sleep 1
		echo 0 > /sys/class/leds/right-green-led/brightness
	done
else
	echo 0 > /sys/class/leds/right-green-led/brightness
	echo "One or more images failed! $(cat /tmp/failed)"
	echo "Check /tmp/logs for more information."
	while true; do
		sleep 1
		echo 1 > /sys/class/leds/right-red-led/brightness
		sleep 1
		echo 0 > /sys/class/leds/right-red-led/brightness
	done
fi
) &
