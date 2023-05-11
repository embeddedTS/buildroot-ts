################################################################################
#
# linux-firmware-qca9377
#
################################################################################

LINUX_FIRMWARE_QCA9377_VERSION = 20221214
LINUX_FIRMWARE_QCA9377_SOURCE = linux-firmware-$(LINUX_FIRMWARE_QCA9377_VERSION).tar.xz
LINUX_FIRMWARE_QCA9377_SITE = $(BR2_KERNEL_MIRROR)/linux/kernel/firmware
LINUX_FIRMWARE_QCA9377_INSTALL_IMAGES = YES

LINUX_FIRMWARE_QCA9377_CPE_ID_VENDOR = kernel

# Qualcomm Atheros QCA9377 Bluetooth
ifeq ($(BR2_PACKAGE_LINUX_FIRMWARE_QUALCOMM_9377_BT),y)
LINUX_FIRMWARE_QCA9377_FILES += qca/rampatch_00230302.bin qca/nvm_00230302.bin
LINUX_FIRMWARE_QCA9377_ALL_LICENSE_FILES += LICENSE.qcom
endif

ifneq ($(LINUX_FIRMWARE_QCA9377_FILES)$(LINUX_FIRMWARE_QCA9377_DIRS),)

define LINUX_FIRMWARE_QCA9377_BUILD_CMDS
	cd $(@D) && \
	$(TAR) cf br-firmware.tar $(sort $(LINUX_FIRMWARE_QCA9377_FILES) $(LINUX_FIRMWARE_QCA9377_DIRS))
endef

# Most firmware files are under a proprietary license, so no need to
# repeat it for every selections above. Those firmwares that have more
# lax licensing terms may still add them on a per-case basis.
LINUX_FIRMWARE_QCA9377_LICENSE += Proprietary

# This file contains some licensing information about all the firmware
# files found in the linux-firmware package, so we always add it, even
# for firmwares that have their own licensing terms.
LINUX_FIRMWARE_QCA9377_ALL_LICENSE_FILES += WHENCE

# Some license files may be listed more than once, so we have to remove
# duplicates
LINUX_FIRMWARE_QCA9377_LICENSE_FILES = $(sort $(LINUX_FIRMWARE_QCA9377_ALL_LICENSE_FILES))

# Some firmware are distributed as a symlink, for drivers to load them using a
# defined name other than the real one. Since 9cfefbd7fbda ("Remove duplicate
# symlinks") those symlink aren't distributed in linux-firmware but are created
# automatically by its copy-firmware.sh script during the installation, which
# parses the WHENCE file where symlinks are described. We follow the same logic
# here, adding symlink only for firmwares installed in the target directory.
#
# For testing the presence of firmwares in the target directory we first make
# sure we canonicalize the pointed-to file, to cover the symlinks of the form
# a/foo -> ../b/foo  where a/ (the directory where to put the symlink) does
# not yet exist.
define LINUX_FIRMWARE_QCA9377_INSTALL_FW
	mkdir -p $(1)
	$(TAR) xf $(@D)/br-firmware.tar -C $(1)
	cd $(1) ; \
	sed -r -e '/^Link: (.+) -> (.+)$$/!d; s//\1 \2/' $(@D)/WHENCE | \
	while read f d; do \
		if test -f $$(readlink -m $$(dirname "$$f")/$$d); then \
			mkdir -p $$(dirname "$$f") || exit 1; \
			ln -sf $$d "$$f" || exit 1; \
		fi ; \
	done
endef

endif  # LINUX_FIRMWARE_QCA9377_FILES || LINUX_FIRMWARE_QCA9377_DIRS

define LINUX_FIRMWARE_QCA9377_INSTALL_TARGET_CMDS
	$(call LINUX_FIRMWARE_QCA9377_INSTALL_FW, $(TARGET_DIR)/lib/firmware)
endef

define LINUX_FIRMWARE_QCA9377_INSTALL_IMAGES_CMDS
	$(call LINUX_FIRMWARE_QCA9377_INSTALL_FW, $(BINARIES_DIR))
endef

$(eval $(generic-package))
