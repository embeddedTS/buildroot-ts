################################################################################
#
# ts4100-utils
#
################################################################################

TS4100_UTILS_AUTORECONF = YES
TS4100_UTILS_VERSION = v1.0.1
TS4100_UTILS_SITE = $(call github,embeddedTS,ts4100-utils,$(TS4100_UTILS_VERSION))
TS4100_UTILS_DEPENDENCIES = libgpiod
TS4100_UTILS_LICENSE = BSD-2-Clause
TS4100_UTILS_LICENSE_FILES = LICENSE

$(eval $(autotools-package))
