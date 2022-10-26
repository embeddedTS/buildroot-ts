################################################################################
#
# ts4900-utils
#
################################################################################

TS4900_UTILS_AUTORECONF = YES
TS4900_UTILS_VERSION = ee6ce16965014dec46723aeb6d274918071f58f9
TS4900_UTILS_SITE = $(call github,embeddedTS,ts4900-utils,$(TS4900_UTILS_VERSION))

$(eval $(autotools-package))
