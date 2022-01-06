#!/bin/sh

# SPDX-License-Identifier: BSD-2-Clause
# Copyright (c) 2017-2022 Technologic Systems, Inc. dba embeddedTS

# WARNING! READ BEFORE USING THIS SCRIPT!
# 
# This script uses a number of commands and parses their output.  The output
# of the commands may change from distribution to distribution, or even across
# different releases of the same distribution.  This script is provided as
# a reference to our customers to note what files are important when creating
# a "golden" image for a production process.  It should be used carefully, and
# all image files produced by this script should be throughly checked before
# being officially released.
#
# embeddedTS assumes no responsibility for the end use of this script.

# This script is based on our usual prep_customer_image scripts in the device's
# utilities repository. It has been modified to only really sanitize/prepare
# a base image and not handle all of the checking the script normally does.

# Note that this script is tailored to an end customer preparing an image.
# Some of our standard preparations are not done as they would likely not be
# wanted in an end application
#
#
# Generic tests/preperation include:
#   Remove /etc/ssh/*key*  # Done to ensure each device has unique key
#   Touch the file /firstboot. This is used in Debian to recreate SSH keys
#   Remove /etc/machine-id and touch to force systemd to recreate it on boot
#   Remove /var/lib/dbus/machine-id
#   Remove /var/log/*, only files, leave folder tree intact
#   Remove any packages in /var/cache/apt/archives (equiv. to apt-get clean)
#   Remove /var/backups/*
#   Remove temporary/unique files
#     /.readahead
#     /run/utmp
#     /var/lib/systemd/random-seed
#   Set /root.version-cust to current date
#   Create /md5sums.txt of all of the md5sums of files in rootfs
#

TMP_DIR="${1}"

echo "Removing temporary files, SSL keys, apt-get install files, etc."
rm -rfv "${TMP_DIR}"/etc/ssh/*key*
touch "${TMP_DIR}"/firstboot
rm -rfv "${TMP_DIR}"/etc/machine-id
rm -rfv "${TMP_DIR}"/var/lib/dbus/machine-id

# Needed in some Debian versions to correctly work on the first boot after this
touch "${TMP_DIR}"/etc/machine-id

echo "Removing log files (rm will error if no logs present)"
find "${TMP_DIR}"/var/log/ -type f -print0 | xargs -0 rm -v

echo "Cleaning up apt packages and temp files (apt-get clean)"
rm -rfv "${TMP_DIR}"/var/cache/apt/archives/* "${TMP_DIR}"/var/cache/apt/pkgcache.bin "${TMP_DIR}"/var/cache/apt/srcpkgcache.bin

echo "Removing /var/backups/*"
rm -rfv "${TMP_DIR}"/var/backups/*

echo "Removing temporary/unique files"
rm "${TMP_DIR}"/.readahead "${TMP_DIR}"/run/utmp "${TMP_DIR}"/var/lib/systemd/random-seed

vers=$(date +%Y-%m-%d)
echo "Setting /root.version-cust to ${vers}"
echo "${vers}" > "${TMP_DIR}"/root.version-cust

echo "Creating md5sums.txt md5sums"
(
cd "${TMP_DIR}"/
find . -type f \( ! -name md5sums.txt \) -exec md5sum "{}" + > md5sums.txt
)
