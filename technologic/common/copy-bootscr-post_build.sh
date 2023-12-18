#!/bin/bash -e

# Copy boot.scr from output folder to boot folder in target
install -m 644 "${BINARIES_DIR}/boot.scr" "${TARGET_DIR}/boot/"
