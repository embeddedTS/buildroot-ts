################################################################################
#
# ts4900-utils
#
################################################################################

TS4900_UTILS_AUTORECONF = YES
TS4900_UTILS_VERSION = v1.0.0
TS4900_UTILS_SITE = $(call github,embeddedTS,ts4900-utils,$(TS4900_UTILS_VERSION))
TS4900_UTILS_LICENSE = BSD-2-Clause
TS4900_UTILS_LICENSE_FILES = LICENSE

$(eval $(autotools-package))
