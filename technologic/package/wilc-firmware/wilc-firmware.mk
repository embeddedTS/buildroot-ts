################################################################################
#
# ATWILC1000/3000 Firmware
#
################################################################################

# The version names are the release tags available in the repo
ifeq ($(BR2_PACKAGE_WILC_FIRMWARE_15_5),y)
WILC_FIRMWARE_VERSION = wilc_linux_15_5
else ifeq ($(BR2_PACKAGE_WILC_FIRMWARE_15_4),y)
WILC_FIRMWARE_VERSION = wilc_linux_15_4
else ifeq ($(BR2_PACKAGE_WILC_FIRMWARE_15_3_1),y)
WILC_FIRMWARE_VERSION = wilc_linux_15_3_1
else ifeq ($(BR2_PACKAGE_WILC_FIRMWARE_15_3),y)
WILC_FIRMWARE_VERSION = wilc_linux_15_3
else ifeq ($(BR2_PACKAGE_WILC_FIRMWARE_15_2_1),y)
WILC_FIRMWARE_VERSION = wilc_linux_15_2_1
else ifeq ($(BR2_PACKAGE_WILC_FIRMWARE_15_2),y)
WILC_FIRMWARE_VERSION = wilc_linux_15_2
else ifeq ($(BR2_PACKAGE_WILC_FIRMWARE_15_1),y)
WILC_FIRMWARE_VERSION = wilc_linux_15_01
else ifeq ($(BR2_PACKAGE_WILC_FIRMWARE_15_0),y)
WILC_FIRMWARE_VERSION = WILC_LINUX_15_00
endif

WILC_FIRMWARE_SITE = $(call github,linux4wilc,firmware,$(WILC_FIRMWARE_VERSION))

WILC_FIRMWARE_LICENSE = PROPRIETARY

define WILC_FIRMWARE_INSTALL_TARGET_CMDS
	$(INSTALL) -d -m 0755 $(TARGET_DIR)/lib/firmware/mchp/
        $(INSTALL) -m 0644 -D $(@D)/wilc*.bin $(TARGET_DIR)/lib/firmware/mchp/
endef


$(eval $(generic-package))
