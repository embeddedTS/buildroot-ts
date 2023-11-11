################################################################################
#
# lv_drivers
#
################################################################################

LV_DRIVERS_VERSION = v8.3.0
LV_DRIVERS_SITE = $(call github,lvgl,lv_drivers,$(LV_DRIVERS_VERSION))
LV_DRIVERS_INSTALL_STAGING = YES
LV_DRIVERS_CONF_OPTS = -DCMAKE_C_FLAGS="-I$(STAGING_DIR)/usr/include/lvgl/" -DCMAKE_CXX_FLAGS="-I$(STAGING_DIR)/usr/include/lvgl/"
LV_DRIVERS_LICENSE = MIT
LV_DRIVERS_LICENSE_FILES = LICENSE
# Note that there may be other dependencies, however those are driven by
# lv_drv_conf.h options and its not easy to specify those without either
# directly parsing the conf file OR using buildroot options to generate
# the conf file.
#
# For now, just assume its use will need libinput
LV_DRIVERS_DEPENDENCIES = liblvgl libinput

# Copy lv_drv_conf.h to the download dir
# If from a remote URL, the EXTRA_DOWNLOADS variable can easily be used.
# If a local path, extract that path and just copy it manually
LV_DRIVERS_LVDRVCONF = $(call qstrip,$(BR2_PACKAGE_LV_DRIVERS_LVDRVCONF))
LV_DRIVERS_LVDRVCONF_BN = $(notdir $(LV_DRIVERS_LVDRVCONF))
LV_DRIVERS_EXTRA_DOWNLOADS = $(filter ftp://% http://% https://%,$(LV_DRIVERS_LVDRVCONF))
ifeq ($(LV_DRIVERS_EXTRA_DOWNLOADS),)
ifneq ($(LV_DRIVERS_LVDRVCONF),)
define LV_DRIVERS_COPY_LVDRVCONF_TO_DL_DIR
	cp "$(LV_DRIVERS_LVDRVCONF)" "$(LV_DRIVERS_DL_DIR)"
endef
LV_DRIVERS_POST_DOWNLOAD_HOOKS += LV_DRIVERS_COPY_LVDRVCONF_TO_DL_DIR
endif
endif

define LV_DRIVERS_COPY_LVDRVCONF_TO_BUILD_DIR
	cp "$(LV_DRIVERS_DL_DIR)/$(LV_DRIVERS_LVDRVCONF_BN)" "$(@D)/../lv_drv_conf.h"
endef
LV_DRIVERS_POST_EXTRACT_HOOKS += LV_DRIVERS_COPY_LVDRVCONF_TO_BUILD_DIR

$(eval $(cmake-package))
