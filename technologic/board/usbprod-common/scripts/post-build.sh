#!/bin/bash -e

# Get defconfig name
CONFIG="${BR2_CONFIG}"
DEFCONFIG=$(grep "^BR2_DEFCONFIG=" "${CONFIG}" | cut -d '"' -f 2)
basename "${DEFCONFIG}" > "${TARGET_DIR}/etc/buildroot_defconfig"

# Get git hash of buildroot-ts, abbreviated, mark if dirty
(cd "${BR2_EXTERNAL_TECHNOLOGIC_PATH}" && git describe --abbrev=12 --dirty --always) > "${TARGET_DIR}/etc/buildroot_hash"

# Build time
date -Iminutes -u > "${TARGET_DIR}/etc/build_time"
