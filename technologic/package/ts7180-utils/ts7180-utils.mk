################################################################################
#
# ts7180-utils
#
################################################################################

TS7180_UTILS_AUTORECONF = YES
TS7180_UTILS_VERSION = v1.0.2
TS7180_UTILS_SITE = $(call github,embeddedTS,ts7180-utils,$(TS7180_UTILS_VERSION))
TS7180_UTILS_LICENSE = BSD-2-Clause
TS7180_UTILS_LICENSE_FILES = LICENSE

$(eval $(autotools-package))
