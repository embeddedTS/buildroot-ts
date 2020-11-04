#!/bin/sh

mkdir /mnt/sd
mkdir /mnt/emmc
mkdir /tmp/logs

echo 0 > /sys/class/leds/green-led/brightness
echo 1 > /sys/class/leds/red-led/brightness
### MicroSD ###
if [ -e /mnt/usb/sdimage.tar.bz2 ] || [ -e /mnt/usb/sdimage.tar.xz ] ; then
	echo "======= Writing SD card filesystem ========"

	(
# Don't touch the newlines or add tabs/spaces from here to EOF
fdisk /dev/mmcblk0 <<EOF
o
n
p
1


w
EOF
# </fdisk commands>
		if [ $? != 0 ]; then
			echo "fdisk mmcblk0" >> /tmp/failed
		fi

		mkfs.ext4 -O ^metadata_csum,^64bit /dev/mmcblk0p1 -q < /dev/null
		if [ $? != 0 ]; then
			echo "mke2fs mmcblk0" >> /tmp/failed
		fi
		mount /dev/mmcblk0p1 /mnt/sd/
		if [ $? != 0 ]; then
			echo "mount mmcblk0" >> /tmp/failed
		fi

		if [ -e /mnt/usb/sdimage.tar.bz2 ] ; then
			bzcat /mnt/usb/sdimage.tar.bz2 | tar -x -C /mnt/sd
			if [ $? != 0 ]; then
				echo "tar mmcblk0" >> /tmp/failed
			fi
		else # It is an xz image
			xzcat /mnt/usb/sdimage.tar.xz | tar -x -C /mnt/sd
			if [ $? != 0 ]; then
				echo "tar mmcblk0" >> /tmp/failed
			fi
		fi
		sync

		if [ -e "/mnt/sd/md5sums.txt" ]; then
			LINES=$(wc -l /mnt/sd/md5sums.txt  | cut -f 1 -d ' ')
			if [ "${LINES}" = 0 ]; then
				echo "==========MD5sum file blank==========="
				echo "mmcblk0 md5sum file is blank" >> /tmp/failed
			fi
			# Drop caches so we have to reread all files
			echo 3 > /proc/sys/vm/drop_caches
			cd /mnt/sd/
			md5sum -c md5sums.txt > /tmp/sd_md5sums
			if [ $? != 0 ]; then
				echo "==========SD VERIFY FAILED==========="
				echo "mmcblk0 filesystem verify" >> /tmp/failed
			fi
			cd /
		fi

		umount /mnt/sd/
	) > /tmp/logs/sd-writefs 2>&1 &
elif [ -e /mnt/usb/sdimage.dd.bz2 ] || [ -e /mnt/usb/sdimage.dd.xz ]; then
	echo "======= Writing SD card disk image ========"
	(
		if [ -e /mnt/usb/sdimage.dd.bz2 ] ; then
		  bzcat /mnt/usb/sdimage.dd.bz2 | dd bs=4M of=/dev/mmcblk0
		  BYTES="$(bzcat /mnt/usb/sdimage.dd.bz2  | wc -c)"
		else
		  xzcat /mnt/usb/sdimage.dd.xz | dd bs=4M of=/dev/mmcblk0
		  BYTES="$(xzcat /mnt/usb/sdimage.dd.xz | wc -c)"
		fi

		if [ -e /mnt/usb/sdimage.dd.md5 ]; then
			EXPECTED=$(cut -f 1 -d ' ' /mnt/usb/sdimage.dd.md5)
			ACTUAL=$(head /dev/mmcblk0 -c "${BYTES}" | md5sum | cut -f 1 -d ' ')
			if [ "$ACTUAL" != "$EXPECTED" ]; then
				echo "mmcblk0 dd verify" >> /tmp/failed
			fi
		fi
	) > /tmp/logs/sd-writeimage 2>&1 &
fi

### EMMC ###
if [ -e /mnt/usb/emmcimage.tar.bz2 ] || [ -e /mnt/usb/emmcimage.tar.xz ]; then
	echo "======= Writing eMMC filesystem ========"
	(

# Don't touch the newlines or add tabs from here to EOF
fdisk /dev/mmcblk1 <<EOF
o
n
p
1


w
EOF
# </fdisk commands>
		if [ $? != 0 ]; then
			echo "fdisk mmcblk1" >> /tmp/failed
		fi
		mkfs.ext4 -O ^metadata_csum,^64bit /dev/mmcblk1p1 -q < /dev/null
		if [ $? != 0 ]; then
			echo "mke2fs mmcblk1" >> /tmp/failed
		fi
		mount /dev/mmcblk1p1 /mnt/emmc/
		if [ $? != 0 ]; then
			echo "mount mmcblk1" >> /tmp/failed
		fi

		if [ -e /mnt/usb/emmcimage.tar.bz2 ] ; then
			bzcat /mnt/usb/emmcimage.tar.bz2 | tar -x -C /mnt/emmc
			if [ $? != 0 ]; then
				echo "tar mmcblk1" >> /tmp/failed
			fi
		else # It is an xz image
			xzcat /mnt/usb/emmcimage.tar.xz | tar -x -C /mnt/emmc
			if [ $? != 0 ]; then
				echo "tar mmcblk1" >> /tmp/failed
			fi
		fi
		sync

		if [ -e "/mnt/emmc/md5sums.txt" ]; then
			LINES=$(wc -l /mnt/emmc/md5sums.txt  | cut -f 1 -d ' ')
			if [ "${LINES}" = 0 ]; then
				echo "==========MD5sum file blank==========="
				echo "mmcblk1 md5sum file is blank" >> /tmp/failed
			fi
			# Drop caches so we have to reread all files
			echo 3 > /proc/sys/vm/drop_caches
			cd /mnt/emmc/
			md5sum -c md5sums.txt > /tmp/emmc_md5sums
			if [ $? != 0 ]; then
				echo "mmcblk1 filesystem verify" >> /tmp/failed
			fi
			cd /
		fi

		umount /mnt/emmc/
	) > /tmp/logs/emmc-writefs 2>&1 &
elif [ -e /mnt/usb/emmcimage.dd.bz2 ] || [ -e /mnt/usb/emmcimage.dd.xz ]; then
	echo "======= Writing eMMC disk image ========"
	(
		if [ -e /mnt/usb/emmcimage.dd.bz2 ] ; then
		  bzcat /mnt/usb/emmcimage.dd.bz2 | dd bs=4M of=/dev/mmcblk1
		  BYTES=$(bzcat /mnt/usb/emmcimage.dd.bz2  | wc -c)
		else
		  xzcat /mnt/usb/emmcimage.dd.xz | dd bs=4M of=/dev/mmcblk1
		  BYTES=$(xzcat /mnt/usb/emmcimage.dd.xz  | wc -c)
		fi

		if [ -e /mnt/usb/emmcimage.dd.md5 ]; then
			EXPECTED=$(cut -f 1 -d ' ' /mnt/usb/emmcimage.dd.md5)
			ACTUAL=$(head /dev/mmcblk1 -c "${BYTES}" | md5sum | cut -f 1 -d ' ')
			if [ "$ACTUAL" != "$EXPECTED" ]; then
				echo "mmcblk1 dd verify" >> /tmp/failed
			fi
		fi
	) > /tmp/logs/emmc-writeimage 2>&1 &
fi

if [ -e /mnt/usb/u-boot.imx ]; then
	echo "========== Writing new U-boot image =========="
	(
	echo 0 > /sys/block/mmcblk1boot0/force_ro
	dd bs=512 seek=2 if=/mnt/usb/u-boot.imx of=/dev/mmcblk1boot0
	if [ -e /mnt/usb/u-boot.imx.md5 ]; then
		BYTES=$(wc -c /mnt/usb/u-boot.imx)
		EXPECTED=$(cut -f 1 -d ' ' /mnt/usb/u-boot.imx.md5)
		ACTUAL=$(dd if=/dev/mmcblk1boot0 bs=4M | dd skip=2 bs=512 | dd bs=1 count="${BYTES}" | md5sum | cut -f 1 -d ' ')
		if [ "${ACTUAL}" != "${EXPECTED}" ]; then
			echo "mmcblk1boot0 dd verify" >> /tmp/failed
		fi
	fi
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
