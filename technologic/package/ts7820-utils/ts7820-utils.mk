################################################################################
#
# ts7820-utils
#
################################################################################

TS7820_UTILS_AUTORECONF = YES
TS7820_UTILS_VERSION = v1.0.0
TS7820_UTILS_SITE = $(call github,embeddedTS,ts7820-utils,$(TS7820_UTILS_VERSION))
TS7820_UTILS_LICENSE = BSD-2-Clause
TS7820_UTILS_LICENSE_FILES = LICENSE

$(eval $(autotools-package))
