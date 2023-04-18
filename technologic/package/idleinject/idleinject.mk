################################################################################
#
# idleinject
#
################################################################################

IDLEINJECT_VERSION = v1.0.1
IDLEINJECT_SITE = $(call github,embeddedTS,idleinject,$(IDLEINJECT_VERSION))
IDLEINJECT_LICENSE = BSD-2-Clause
IDLEINJECT_LICENSE_FILES = LICENSE

ifeq ($(BR2_PACKAGE_IDLEINJECT_REDLED),y)
define IDLEINJECT_REDLED_ENABLE
	$(SED) 's/LEDARG=\"\"/LEDARG=\"--led \/sys\/class\/leds\/red\:status\/brightness\"/' \
		$(TARGET_DIR)/etc/init.d/S18idleinject
endef
endif

define IDLEINJECT_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 755 \
		$(BR2_EXTERNAL_TECHNOLOGIC_PATH)/package/idleinject/S18idleinject \
		$(TARGET_DIR)/etc/init.d/S18idleinject

	$(SED) s/MAXTEMP/$(call qstrip,$(BR2_PACKAGE_IDLEINJECT_MAXTEMP))/ \
		$(TARGET_DIR)/etc/init.d/S18idleinject

	$(IDLEINJECT_REDLED_ENABLE)

endef

$(eval $(meson-package))
