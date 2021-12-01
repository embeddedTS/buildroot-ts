#!/bin/sh

mkdir /mnt/sd
mkdir /mnt/emmc
mkdir /mnt/sata
mkdir /tmp/logs

### MicroSD ###
if [ -e /mnt/usb/sdimage.tar.bz2 ]; then
	echo "======= Writing SD card filesystem ========"

	(
# Don't touch the newlines or add tabs/spaces from here to EOF
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
		mount /dev/mmcblk1p1 /mnt/sd/
		if [ $? != 0 ]; then
			echo "mount mmcblk1" >> /tmp/failed
		fi
		bzcat /mnt/usb/sdimage.tar.bz2 | tar -x -C /mnt/sd
		if [ $? != 0 ]; then
			echo "tar mmcblk1" >> /tmp/failed
		fi
		sync

		if [ -e "/mnt/sd/md5sums.txt" ]; then
			LINES=$(wc -l /mnt/sd/md5sums.txt  | cut -f 1 -d ' ')
			if [ $LINES = 0 ]; then
				echo "==========MD5sum file blank==========="
				echo "mmcblk1 md5sum file is blank" >> /tmp/failed
			fi
			# Drop caches so we have to reread all files
			echo 3 > /proc/sys/vm/drop_caches
			cd /mnt/sd/
			md5sum -c md5sums.txt > /tmp/sd_md5sums
			if [ $? != 0 ]; then
				echo "==========SD VERIFY FAILED==========="
				echo "mmcblk1 filesystem verify" >> /tmp/failed
			fi
			cd /
		fi

		umount /mnt/sd/
	) > /tmp/logs/sd-writefs 2>&1 &
elif [ -e /mnt/usb/sdimage.dd.bz2 ]; then
	echo "======= Writing SD card disk image ========"
	(
		bzcat /mnt/usb/sdimage.dd.bz2 | dd bs=4M of=/dev/mmcblk1
		if [ -e /mnt/usb/sdimage.dd.md5 ]; then
			BYTES="$(bzcat /mnt/usb/sdimage.dd.bz2  | wc -c)"
			EXPECTED="$(cat /mnt/usb/sdimage.dd.md5 | cut -f 1 -d ' ')"
			ACTUAL=$(dd if=/dev/mmcblk1 bs=4M | dd bs=1 count=$BYTES | md5sum)
			if [ "$ACTUAL" != "$EXPECTED" ]; then
				echo "mmcblk1 dd verify" >> /tmp/failed
			fi
		fi
	) > /tmp/logs/sd-writeimage 2>&1 &
fi

### EMMC ###
if [ -e /mnt/usb/emmcimage.tar.bz2 ]; then
	echo "======= Writing eMMC card filesystem ========"
	(

# Don't touch the newlines or add tabs from here to EOF
fdisk /dev/mmcblk2 <<EOF
o
n
p
1


w
EOF
# </fdisk commands>
		if [ $? != 0 ]; then
			echo "fdisk mmcblk2" >> /tmp/failed
		fi
		mkfs.ext4 -O ^metadata_csum,^64bit /dev/mmcblk2p1 -q < /dev/null
		if [ $? != 0 ]; then
			echo "mke2fs mmcblk2" >> /tmp/failed
		fi
		mount /dev/mmcblk2p1 /mnt/emmc/
		if [ $? != 0 ]; then
			echo "mount mmcblk2" >> /tmp/failed
		fi
		bzcat /mnt/usb/emmcimage.tar.bz2 | tar -x -C /mnt/emmc
		if [ $? != 0 ]; then
			echo "tar mmcblk2" >> /tmp/failed
		fi
		sync

		if [ -e "/mnt/emmc/md5sums.txt" ]; then
			LINES=$(wc -l /mnt/emmc/md5sums.txt  | cut -f 1 -d ' ')
			if [ $LINES = 0 ]; then
				echo "==========MD5sum file blank==========="
				echo "mmcblk2 md5sum file is blank" >> /tmp/failed
			fi
			# Drop caches so we have to reread all files
			echo 3 > /proc/sys/vm/drop_caches
			cd /mnt/emmc/
			md5sum -c md5sums.txt > /tmp/emmc_md5sums
			if [ $? != 0 ]; then
				echo "mmcblk2 filesystem verify" >> /tmp/failed
			fi
			cd /
		fi

		umount /mnt/emmc/
	) > /tmp/logs/emmc-writefs 2>&1 &
elif [ -e /mnt/usb/emmcimage.dd.bz2 ]; then
	echo "======= Writing eMMC disk image ========"
	(
		bzcat /mnt/usb/emmcimage.dd.bz2 | dd bs=4M of=/dev/mmcblk2
		if [ -e /mnt/usb/emmcimage.dd.md5 ]; then
			BYTES="$(bzcat /mnt/usb/emmcimage.dd.bz2  | wc -c)"
			EXPECTED="$(cat /mnt/usb/emmcimage.dd.md5 | cut -f 1 -d ' ')"
			ACTUAL=$(dd if=/dev/mmcblk2 bs=4M | dd bs=1 count=$BYTES | md5sum)
			if [ "$ACTUAL" != "$EXPECTED" ]; then
				echo "mmcblk2 dd verify" >> /tmp/failed
			fi
		fi
	) > /tmp/logs/emmc-writeimage 2>&1 &
fi

### SATA ###
if [ -e /mnt/usb/sataimage.tar.bz2 -o -e /mnt/usb/sataimage.dd.bz2 ]; then
	# Sanity check SATA has sda1.  It should, but if there is any issue
	# with the drive it may not be recognized and this would be the usb
	readlink /sys/class/block/sda | grep sata
	if [ $? != 0 ]; then
		echo "sata not found" >> /tmp/failed
	else 
		if [ -e /mnt/usb/sataimage.tar.bz2 ]; then
			echo "======= Writing SATA drive filesystem ========"
			(
				# Don't touch the newlines or add tabs from here to EOF
				fdisk /dev/sda <<EOF
o
n
p
1


w
EOF
				# </fdisk commands>
				if [ $? != 0 ]; then
					echo "fdisk sda1" >> /tmp/failed
				fi

				mkfs.ext4 -O ^metadata_csum,^64bit /dev/sda1 -q < /dev/null
				if [ $? != 0 ]; then
					echo "mke2fs sda1" >> /tmp/failed
				fi
				mount /dev/sda1 /mnt/sata/
				if [ $? != 0 ]; then
					echo "mount sda1" >> /tmp/failed
				fi
				bzcat /mnt/usb/sataimage.tar.bz2 | tar -x -C /mnt/sata
				if [ $? != 0 ]; then
					echo "tar sda1" >> /tmp/failed
				fi
				sync

				if [ -e "/mnt/sata/md5sums.txt" ]; then
					# Drop caches so we have to reread all files
					echo 3 > /proc/sys/vm/drop_caches
					cd /mnt/sata/
					md5sum -c md5sums.txt > /tmp/sata_md5sums
					if [ $? != 0 ]; then
						echo "sda1 filesystem verify" >> /tmp/failed
					fi
					cd /
				fi

				umount /mnt/sata/
			) > /tmp/logs/sata-writefs 2>&1 &
		elif [ -e /mnt/usb/sataimage.dd.bz2 ]; then
			echo "======= Writing SATA drive disk image ========"
			(
				bzcat /mnt/usb/sataimage.dd.bz2 | dd bs=4M of=/dev/sda
				if [ -e /mnt/usb/sataimage.dd.md5 ]; then
					BYTES="$(bzcat /mnt/usb/sataimage.dd.bz2  | wc -c)"
					EXPECTED="$(cat /mnt/usb/sataimage.dd.md5 | cut -f 1 -d ' ')"
					ACTUAL=$(dd if=/dev/sda bs=4M | dd bs=1 count=$BYTES | md5sum)
					if [ "$ACTUAL" != "$EXPECTED" ]; then
						echo "sda1 dd verify" >> /tmp/failed
					fi
				fi
			) > /tmp/logs/sata-writeimage 2>&1 &
		fi
	fi
fi

### SPI (U-boot) ###
if [ -e /mnt/usb/u-boot.imx ]; then
	(
		BOARD_IMX_TYPE=$(dd if=/dev/mtdblock0 bs=1024 skip=1 count=$((524288/1024)) 2> /dev/null | strings | grep "imx_type=")
		IMAGE_IMX_TYPE=$(dd if=/mnt/usb/u-boot.imx 2> /dev/null  | strings | grep "imx_type=")

		if [ "$BOARD_IMX_TYPE" != "$IMAGE_IMX_TYPE" ]; then
			echo "IMX_TYPE $BOARD_IMX_TYPE and $IMAGE_IMX_TYPE didn't match.  Writing this anyway may brick the board or cause instability." >> /tmp/failed
		else
			dd if=/mnt/usb/u-boot.imx of=/dev/mtdblock0 bs=1024 seek=1
			if [ -e /mnt/usb/u-boot.imx.md5 ]; then
				sync
				# Flush any buffer cache
				echo 3 > /proc/sys/vm/drop_caches

				BYTES="$(ls -l /mnt/usb/u-boot.imx | sed -e 's/[^ ]* *[^ ]* *[^ ]* *[^ ]* *//' -e 's/ .*//')"
				EXPECTED="$(cat /mnt/usb/u-boot.imx.md5 | cut -f 1 -d ' ')"

				# Read back from spi flash
				dd if=/dev/mtdblock0 of=/tmp/uboot-verify.dd bs=1024 skip=1 count=$(($BYTES/1024)) 2> /dev/null
				# truncate extra from last block
				dd if=/tmp/uboot-verify.dd of=/tmp/uboot-verify.imx bs=1 count="$BYTES" 2> /dev/null
				UBOOT_FLASH="$(md5sum /tmp/uboot-verify.imx | cut -f 1 -d ' ')"

				if [ "$UBOOT_FLASH" != "$EXPECTED" ]; then
					echo "u-boot verify failed" >> /tmp/failed
				fi
			fi
		fi

	) > /tmp/logs/spi-bootimg &
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
