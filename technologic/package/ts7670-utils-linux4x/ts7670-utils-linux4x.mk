################################################################################
#
# ts7670-utils-linux4.x
#
################################################################################

TS7670_UTILS_LINUX4X_AUTORECONF = YES
TS7670_UTILS_LINUX4X_VERSION = v2.0.0
TS7670_UTILS_LINUX4X_SITE = $(call github,embeddedTS,ts7670-utils-linux4.x,$(TS7670_UTILS_LINUX4X_VERSION))
TS7670_UTILS_LINUX4X_LICENSE = BSD-2-Clause
TS7670_UTILS_LINUX4X_LICENSE_FILES = LICENSE

$(eval $(autotools-package))
