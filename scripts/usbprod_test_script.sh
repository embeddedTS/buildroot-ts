#!/bin/sh

err_exit() {
	echo "${1}" 1>&2
	exit 1
}

wait_dev_attach() {
	while [ ! -b "${1}" ]; do sleep 1; done
}

wait_dev_detach() {
	while [ -b "${1}" ]; do sleep 1; done
	echo "Insert disk to copy next round of test files"
}

dev_mount() {
	DIR=$(mktemp -d)
	mount "${1}" "${DIR}" || err_exit "mount failed"
	rm "${DIR}"/*image*
	echo "${DIR}"
}

dev_umount() {
	umount "${1}" || err_exit "umount failed"
	rmdir "${1}"
	echo "Disk unmounted! Remove and insert in to UUT to test Image Replicator tool"
	echo ""
}

usage() {
	echo "Usage: $0 --disk <USB disk and partition> [--sata] [--nosd] [--noemmc] [--all]"
	echo ""
	echo "  Test script for proving out Image Replicator process on a platform."
	echo "  This script will attempt to, from a base .tar and .dd, create a"
	echo "  number of files to test compatible names and compression algorithms."
	echo ""
	echo "  It is intended to test each format and compression method at least once,"
	echo "  as well as writing various images to each target media; i.e. SD, eMMC, SATA"
	echo "  This is used to ensure that new platforms, or existing platforms, fully"
	echo "  support all compatible source files with the Image Replicator scripts."
	echo ""
	echo "  If all of the test file variants are not already present in the PWD,"
	echo "  then this script will require image.tar and image.dd to be present"
	echo "  in the PWD so it can create the files from those sources."
	echo ""
	echo "  It is recommended that the image.tar file contains /md5sums.txt, which"
	echo "  is used by the Image Replicator tool to check all of the unpacked files."
	echo ""
	echo "  By default this tests the following source files:"
	echo "    sdimage.tar"
	echo "    sdimage.dd"
	echo "    emmcimage.tar"
	echo "    emmcimage.dd"
	echo ""
	echo "  Testing of SD and eMMC can be disabled by passing --nosd and --noemmc"
	echo "  respectively."
	echo ""
	echo "  For devices with SATA disks present, passing --sata will generate the"
	echo "  following source files:"
	echo "    sataimage.tar"
	echo "    sataimage.dd"
	echo ""
	echo "  For each of the source files, the following compressions are tested:"
	echo "    No compression"
	echo "    gzip (.gz)"
	echo "    bzip2 (.bz2)"
	echo "    xz (.xz)"
	echo ""
	echo "  Normally, to speed up testing, each source file w/ compression is copied"
	echo "  round-robin to each target media. e.g. sdimage.tar, emmcimage.tar.gz together,"
	echo "  then sdimage.tar.bz2, emmcimage.tar.xz together."
	echo "  Passing the --all flag will test each compression and source file for each"
	echo "  target media. e.g. sdimage.tar, emmcimage.tar together, then sdimage.tar.gz,"
	echo "  emmcimage.tar.gz together, etc. It is a more exhaustive, but longer, test."
	echo ""
	echo "  Once this script is run with a USB disk partition, it will wait for that"
	echo "  partition to appear in the system, mount it, and copy a source file for"
	echo "  each supported device before unmounting it. That USB device can then be"
	echo "  booted on a compatible system, and the Image Replicator process will run."
	echo "  Once that is complete, re-insert the USB disk back in to the workstation"
	echo "  and this script will repeate this with the next set of files."
	echo ""
	echo "  In addition to testing good source files, this script intentionally will"
	echo "  generate bad MD5sums for the .dd and .tar (by editing /md5sums.txt) to"
	echo "  ensure failures are properly caught as well."
	echo ""
	echo "  After that, the image capture process is forced to be run by removing all"
	echo "  source files from the USB drive. Allowing the Image Replicator to capture"
	echo "  an image from each present compatible source"
	echo ""
	echo "  This script does not test U-Boot image updating."
	echo ""
	echo "  A pre-formatted USB drive is required. This generally means manually making"
	echo "  a single partition on a USB drive and unpacking the Image Replicator rootfs"
	echo "  to it. It is not recommended to use the Image Replicator .dd file, as this"
	echo "  script first copies source media to the USB disk. Due to the expansion"
	echo "  behavior of the Image Replicator tool, these images may not fit on disk."
	echo ""
	echo ""
	echo "Example Usage:"
	echo "  $0 /dev/sdb1 --nosd"
	echo "  $0 /dev/sdc1 --sata"
	echo ""
}

# Process arguments
DISK=
SD=1
EMMC=1
SATA=0
ALL=0

while :; do
	case $1 in
	  -h|--help|-\?)
		usage
		exit
		;;
	  --disk|-d)
		if [ "$2" ]; then
			DISK=$2
			shift
		else
			err_exit "--disk requires non-empty argument"
		fi
		;;
	  --nosd)
		SD=0
		;;
	  --noemmc)
		EMMC=0
		;;
	  --sata)
		SATA=1
		;;
	  --all)
		ALL=1
		;;
	  -?*)
		;;
	  *)
		break
	esac

	shift
done

if [ -z "${DISK}" ]; then
	usage
	echo ""
	err_exit "Disk must be specified with --disk! e.g. --disk /dev/sdb1"
fi

if [ ${SD} -eq 0 ] && [ ${EMMC} -eq 0 ] && [ ${SATA} -eq 0 ]; then
	echo "No target media specified!"
	err_exit "Must not specify --nosd & --noemmc without --sata. Cannot continue"
fi

if [ $(id -u) -ne 0 ]; then
	echo "This script needs to be run by root!"
	exit 1
fi

# Check that all sources files exist, if not, try to create them. If the needed files
# don't exist, then fail.
IMG_FILES="image.tar image.tar.gz image.tar.xz image.tar.bz2 image.dd image.dd.gz image.dd.xz image.dd.bz2"
FILES="${IMG_FILES} image.dd.md5"
ALL_FILES_EXIST=1
for NAME in ${FILES}; do
	if [ ! -e "${NAME}" ]; then
		ALL_FILES_EXIST=0
	fi
done

if [ ${ALL_FILES_EXIST} -ne 1 ]; then
	if [ ! -e "image.tar" ] || [ ! -e "image.dd" ]; then
		err_exit "Not all needed source files exist in PWD. image.tar nor image.dd" \
		"exist in the PWD either. Cannot create source files. Unable to continue"
	fi
	echo "Creating necessary files from image.tar and image.dd"
	gzip - < image.tar > image.tar.gz &
	bzip2 - < image.tar > image.tar.bz2 &
	xz -2 - < image.tar  > image.tar.xz &
	gzip - < image.dd > image.dd.gz &
	bzip2 - < image.dd > image.dd.bz2 &
	xz -2 - < image.dd > image.dd.xz &
	md5sum image.dd > image.dd.md5 &
	wait
fi

echo "Insert ${DISK} to start loop"

# Set up the whole file list to be positional parameters so we can test
# each source file once by walking over every possible disk.
# Note that, if only testing a single disk, this process can take a while
set -- ${IMG_FILES}

while true; do
	wait_dev_attach "${DISK}"
	DIR=$(dev_mount "${DISK}")
	printf "Copying "
	if [ -n "${1}" ] && [ ${SD} -eq 1 ]; then
		cp "${1}" "${DIR}"/sd"${1}"
		if [ "${1#*.dd}" != "${1}" ] ; then
			cp image.dd.md5 "${DIR}"/sdimage.dd.md5
		fi
		printf "sd%s " "${1}"
		if [ ${ALL} -eq 0 ]; then
			shift
		fi
	fi
	if [ -n "${1}" ] && [ ${EMMC} -eq 1 ]; then
		cp "${1}" "${DIR}"/emmc"${1}"
		if [ "${1#*.dd}" != "${1}" ] ; then
			cp image.dd.md5 "${DIR}"/emmcimage.dd.md5
		fi
		printf "emmc%s " "${1}"
		if [ ${ALL} -eq 0 ]; then
			shift
		fi
	fi
	if [ -n "${1}" ] && [ ${SATA} -eq 1 ]; then
		cp "${1}" "${DIR}"/sata"${1}"
		if [ "${1#*.dd}" != "${1}" ] ; then
			cp image.dd.md5 "${DIR}"/sataimage.dd.md5
		fi
		printf "sata%s " "${1}"
		if [ ${ALL} -eq 0 ]; then
			shift
		fi
	fi
	echo "for testing Image Replicator tool"

	# If ALL set, now shift to the next image type for testing
	if [ ${ALL} -eq 1 ]; then
		shift
	fi

	dev_umount "${DIR}"
	wait_dev_detach "${DISK}"

	if [ -z "${1}" ]; then
		break;
	fi
done

# Create bad md5sum for image.dd and run tests
md5sum image.tar > image.dd.md5.bad
wait_dev_attach "${DISK}"
DIR=$(dev_mount "${DISK}")
printf "Copying "
if [ ${SD} -eq 1 ]; then
	cp "image.dd.xz" "${DIR}"/sdimage.dd.xz
	cp image.dd.md5.bad "${DIR}"/sdimage.dd.md5
	printf "sdimage.dd.xz "
fi
if [ ${EMMC} -eq 1 ]; then
	cp "image.dd.bz2" "${DIR}"/emmcimage.dd.bz2
	cp image.dd.md5.bad "${DIR}"/emmcimage.dd.md5
	printf "emmcimage.dd.bz2 "
fi
if [ ${SATA} -eq 1 ]; then
	cp "image.dd.gz" "${DIR}"/sataimage.dd.gz
	cp image.dd.md5.bad "${DIR}"/sataimage.dd.md5
	printf "sataimage.dd.gz "
fi
echo "WITH BAD MD5SUM FILE! For testing Image Replicator tool"
dev_umount "${DIR}"
rm image.dd.md5.bad
wait_dev_detach "${DISK}"


# Create bad md5sum for image.tar and run tests
cp image.tar image.tar.bad
tar xvf image.tar.bad ./md5sums.txt
md5sum ./image.tar >> md5sums.txt 
tar uvf image.tar.bad ./md5sums.txt 
rm md5sums.txt 
wait_dev_attach "${DISK}"
DIR=$(dev_mount "${DISK}")
printf "Copying "
if [ ${SD} -eq 1 ]; then
	xz -2 - < image.tar.bad > "${DIR}"/sdimage.tar.xz
	printf "sdimage.tar.xz "
fi
if [ ${EMMC} -eq 1 ]; then
	bzip2 - < image.tar.bad > "${DIR}"/emmcimage.tar.bz2
#XXX: printf is wrong
	printf "emmcimage.dd.bz2 "
fi
if [ ${SATA} -eq 1 ]; then
	bzip2 - < image.tar.bad > "${DIR}"/sataimage.tar.gz
	printf "sataimage.tar.gz "
fi
echo "WITH BAD MD5SUM FILE! For testing Image Replicator tool"
dev_umount "${DIR}"
rm image.tar.bad
wait_dev_detach "${DISK}"

wait_dev_attach "${DISK}"
echo "Image capture mode. Removing all image files to let Image Replicator capture disk images on UUT"
DIR=$(dev_mount "${DISK}")
dev_umount "${DIR}"
wait_dev_detach "${DISK}"

echo "DONE!"
