################################################################################
#
# ts7100z-lvgl-ui-demo
#
################################################################################

TS7100Z_LVGL_UI_DEMO_VERSION = v1.0.2
TS7100Z_LVGL_UI_DEMO_SITE = $(call github,embeddedTS,ts7100z-lvgl-ui-demo,$(TS7100Z_LVGL_UI_DEMO_VERSION))
TS7100Z_LVGL_UI_DEMO_CONF_OPTS = -DCMAKE_C_FLAGS="-I$(STAGING_DIR)/usr/include/lvgl/" -DCMAKE_CXX_FLAGS="-I$(STAGING_DIR)/usr/include/lvgl/"
TS7100Z_LVGL_UI_DEMO_LICENSE = BSD-2-Clause
TS7100Z_LVGL_UI_DEMO_LICENSE_FILES = LICENSE
TS7100Z_LVGL_UI_DEMO_DEPENDENCIES = libiio libgpiod liblvgl lv_drivers

$(eval $(cmake-package))
