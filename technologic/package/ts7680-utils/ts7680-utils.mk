################################################################################
#
# ts7680-utils
#
################################################################################

TS7680_UTILS_AUTORECONF = YES
TS7680_UTILS_VERSION = v2.0.0
TS7680_UTILS_SITE = $(call github,embeddedTS,ts7680-utils,$(TS7680_UTILS_VERSION))
TS7680_UTILS_LICENSE = BSD-2-Clause
TS7680_UTILS_LICENSE_FILES = LICENSE

$(eval $(autotools-package))
