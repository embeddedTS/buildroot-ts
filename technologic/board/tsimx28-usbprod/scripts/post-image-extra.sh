#!/bin/bash -e

# This is currently the only existing script like this, so, the actual format
# and calling args may change over time. However, for now, the only arguments
# passed are the script directory and the directory that we are going to copy
# specific files in to.

# The tsimx28 series support in Image Replicator is unique in some of the
# additional steps needed. Including copying the U-Boot binary and the older
# style tsinit to the final tarball. The good news is that this script doesn't
# need to do anything other than copy them, the old tsinit script does the
# heavy lifting at runtime.

THIS_DIR="${1}"
if [ -z "${THIS_DIR}" ]; then
	exit 1
fi

DEST_DIR="${2}"
if [ -z "${DEST_DIR}" ]; then
	exit 1
fi

# Copy U-Boot binaries
# This process is a bit more complex in that in order to boot Image Replicator
# on these platforms, they first need to boot their own kernel since the
# bootloader and kernel are on the same boot media.
cp "${BINARIES_DIR}"/*-uboot.sd "${DEST_DIR}"

# Copy old style tsinit script to USB
# Compatible platforms may not use U-Boot and instead may be booting from
# an initramfs that mounts the USB drive and executes a script
cp "${THIS_DIR}"/tsinit "${DEST_DIR}"
