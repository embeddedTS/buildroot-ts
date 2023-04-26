################################################################################
#
# TS-7670 U-Boot blob
#
################################################################################

TS7670_UBOOT_VERSION = 20230301
TS7670_UBOOT_SOURCE = ts7670-$(TS7670_UBOOT_VERSION).sd
TS7670_UBOOT_SITE = https://files.embeddedts.com/ts-arm-sbc/ts-7670-linux/binaries/u-boot

# License is derived from U-Boot base license
TS7670_UBOOT_LICENSE = GPL-2.0+

define TS7670_UBOOT_EXTRACT_CMDS
	cp $(TS7670_UBOOT_DL_DIR)/$(TS7670_UBOOT_SOURCE) $(@D)
endef

define TS7670_UBOOT_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0644 -D $(@D)/$(TS7670_UBOOT_SOURCE) $(BINARIES_DIR)/ts7670-uboot.sd
endef

$(eval $(generic-package))
