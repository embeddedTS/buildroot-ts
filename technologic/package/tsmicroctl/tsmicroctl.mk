################################################################################
#
# tsmicroctl
#
################################################################################

TSMICROCTL_VERSION = v1.0.3
TSMICROCTL_SITE = $(call github,embeddedTS,tsmicroctl,$(TSMICROCTL_VERSION))
TSMICROCTL_LICENSE = BSD-2-Clause
TSMICROCTL_LICENSE_FILES = LICENSE

define TSMICROCTL_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 755 \
		$(BR2_EXTERNAL_TECHNOLOGIC_PATH)/package/tsmicroctl/S99tsmicroctl \
		$(TARGET_DIR)/etc/init.d/S99tsmicroctl

	$(SED) s/SILO_PCT/$(call qstrip,$(BR2_PACKAGE_TSMICROCTL_PCT))/ \
		$(TARGET_DIR)/etc/init.d/S99tsmicroctl
endef

$(eval $(meson-package))
