#!/bin/bash

set -e

echo "Generating U-Boot script"
mkimage -A arm -T script -C none -n 'boot' -d "${TARGET_DIR}"/boot/boot.source "${TARGET_DIR}"/boot/boot.scr

