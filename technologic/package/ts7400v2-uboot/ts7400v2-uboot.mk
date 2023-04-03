################################################################################
#
# TS-7400-V2 U-Boot blob
#
################################################################################

TS7400V2_UBOOT_VERSION = 20230301
TS7400V2_UBOOT_SOURCE = ts7400v2-$(TS7400V2_UBOOT_VERSION).sd
TS7400V2_UBOOT_SITE = https://files.embeddedts.com/ts-arm-sbc/ts-7400_V2-linux/binaries/u-boot

# License is derived from U-Boot base license
TS7400V2_UBOOT_LICENSE = GPL-2.0+

define TS7400V2_UBOOT_EXTRACT_CMDS
	cp $(TS7400V2_UBOOT_DL_DIR)/$(TS7400V2_UBOOT_SOURCE) $(@D)
endef


define TS7400V2_UBOOT_INSTALL_TARGET_CMDS
        $(INSTALL) -m 0644 -D $(@D)/$(TS7400V2_UBOOT_SOURCE) $(BINARIES_DIR)/ts7400v2-uboot.sd
endef


$(eval $(generic-package))

