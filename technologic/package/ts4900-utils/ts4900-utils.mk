################################################################################
#
# ts4900-utils
#
################################################################################

TS4900_UTILS_AUTORECONF = YES
TS4900_UTILS_VERSION = 0d77ae39d82fe8846fb8e4c06c31bbc69ecba77b
TS4900_UTILS_SITE = $(call github,embeddedTS,ts4900-utils,$(TS4900_UTILS_VERSION))

$(eval $(autotools-package))
