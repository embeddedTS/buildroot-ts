################################################################################
#
# ts7100-utils
#
################################################################################

TS7100_UTILS_AUTORECONF = YES
TS7100_UTILS_VERSION = v1.0.3
TS7100_UTILS_SITE = $(call github,embeddedTS,ts7100-utils,$(TS7100_UTILS_VERSION))
TS7100_UTILS_DEPENDENCIES = libgpiod
TS7100_UTILS_LICENSE = BSD-2-Clause
TS7100_UTILS_LICENSE_FILES = LICENSE

$(eval $(autotools-package))
