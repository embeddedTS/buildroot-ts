################################################################################
#
# liblvgl
#
################################################################################

LIBLVGL_VERSION = v8.3.9
LIBLVGL_SITE = $(call github,lvgl,lvgl,$(LIBLVGL_VERSION))
LIBLVGL_INSTALL_STAGING = YES
LIBLVGL_LICENSE = MIT
LIBLVGL_LICENSE_FILES = LICENCE.txt

# Copy lv_conf.h to the download dir
# If from a remote URL, the EXTRA_DOWNLOADS variable can easily be used.
# If a local path, extract that path and just copy it manually
LIBLVGL_LVCONF = $(call qstrip,$(BR2_PACKAGE_LIBLVGL_LVCONF))
LIBLVGL_LVCONF_BN = $(notdir $(LIBLVGL_LVCONF))
LIBLVGL_EXTRA_DOWNLOADS = $(filter ftp://% http://% https://%,$(LIBLVGL_LVCONF))
ifeq ($(LIBLVGL_EXTRA_DOWNLOADS),)
ifneq ($(LIBLVGL_LVCONF),)
define LIBLVGL_COPY_LVCONF_TO_DL_DIR
	cp "$(LIBLVGL_LVCONF)" "$(LIBLVGL_DL_DIR)"
endef
LIBLVGL_POST_DOWNLOAD_HOOKS += LIBLVGL_COPY_LVCONF_TO_DL_DIR
endif
endif

define LIBLVGL_COPY_LVCONF_TO_BUILD_DIR
	cp "$(LIBLVGL_DL_DIR)/$(LIBLVGL_LVCONF_BN)" "$(@D)/lv_conf.h"
endef
LIBLVGL_POST_EXTRACT_HOOKS += LIBLVGL_COPY_LVCONF_TO_BUILD_DIR

$(eval $(cmake-package))
