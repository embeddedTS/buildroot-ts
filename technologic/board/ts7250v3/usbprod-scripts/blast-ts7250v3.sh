#!/bin/sh

mkdir /mnt/sd
mkdir /mnt/emmc
mkdir /tmp/logs

echo 0 > /sys/class/leds/green-led/brightness
echo 1 > /sys/class/leds/red-led/brightness

### EMMC ###
if [ -e /mnt/usb/emmcimage.tar.bz2 ]; then
	echo "======= Writing eMMC card filesystem ========"
	(
		sgdisk --zap-all /dev/mmcblk0

		# Create one single GPT linux partition
		if ! sgdisk -n 0:0:0 -t 0:8300 /dev/mmcblk0; then
		    set_fail "emmc sgdisk new partition failed"
		fi
		if [ $? != 0 ]; then
			echo "sgdisk mmcblk0" >> /tmp/failed
		fi
		mkfs.ext4 -O ^metadata_csum,^64bit /dev/mmcblk0p1 -q < /dev/null
		if [ $? != 0 ]; then
			echo "mke2fs mmcblk0" >> /tmp/failed
		fi
		mount /dev/mmcblk0p1 /mnt/emmc/
		if [ $? != 0 ]; then
			echo "mount mmcblk0" >> /tmp/failed
		fi
		bzcat /mnt/usb/emmcimage.tar.bz2 | tar -x -C /mnt/emmc
		if [ $? != 0 ]; then
			echo "tar mmcblk0" >> /tmp/failed
		fi
		sync

		if [ -e "/mnt/emmc/md5sums.txt" ]; then
			LINES=$(wc -l /mnt/emmc/md5sums.txt  | cut -f 1 -d ' ')
			if [ $LINES = 0 ]; then
				echo "==========MD5sum file blank==========="
				echo "mmcblk0 md5sum file is blank" >> /tmp/failed
			fi
			# Drop caches so we have to reread all files
			echo 3 > /proc/sys/vm/drop_caches
			cd /mnt/emmc/
			md5sum -c md5sums.txt > /tmp/emmc_md5sums
			if [ $? != 0 ]; then
				echo "mmcblk0 filesystem verify" >> /tmp/failed
			fi
			cd /
		fi

		umount /mnt/emmc/
	) > /tmp/logs/emmc-writefs 2>&1 &
elif [ -e /mnt/usb/emmcimage.dd.bz2 ]; then
	echo "======= Writing eMMC disk image ========"
	(
		bzcat /mnt/usb/emmcimage.dd.bz2 | dd bs=4M of=/dev/mmcblk0
		if [ -e /mnt/usb/emmcimage.dd.md5 ]; then
			BYTES="$(bzcat /mnt/usb/emmcimage.dd.bz2  | wc -c)"
			EXPECTED="$(cat /mnt/usb/emmcimage.dd.md5 | cut -f 1 -d ' ')"
			ACTUAL=$(dd if=/dev/mmcblk0 bs=4M | dd bs=1 count=$BYTES | md5sum)
			if [ "$ACTUAL" != "$EXPECTED" ]; then
				echo "mmcblk0 dd verify" >> /tmp/failed
			fi
		fi
	) > /tmp/logs/emmc-writeimage 2>&1 &
fi

if [ -e /mnt/usb/u-boot-dtb.bin ] && [ -e /mnt/usb/SPL ]; then
	echo "==========Writing new U-boot image =========="
	(
	echo 0 > /sys/block/mmcblk0boot0/force_ro
	dd bs=512 seek=2 if=/mnt/usb/SPL of=/dev/mmcblk0boot0
	dd bs=512 seek=138 if="/tmp/u-boot-dtb.img" of=/dev/mmcblk0boot0
	) > /tmp/logs/u-boot-writeimage 2>&1 &
fi

sync
wait

(
# Blink green led if it works.  Blink red if bad things happened
if [ ! -e /tmp/failed ]; then
	echo 0 > /sys/class/leds/red-led/brightness
	echo "All images wrote correctly!"
	while true; do
		sleep 1
		echo 1 > /sys/class/leds/green-led/brightness
		sleep 1
		echo 0 > /sys/class/leds/green-led/brightness
	done
else
	echo 0 > /sys/class/leds/green-led/brightness
	echo "One or more images failed! $(cat /tmp/failed)"
	echo "Check /tmp/logs for more information."
	while true; do
		sleep 1
		echo 1 > /sys/class/leds/red-led/brightness
		sleep 1
		echo 0 > /sys/class/leds/red-led/brightness
	done
fi
) &
