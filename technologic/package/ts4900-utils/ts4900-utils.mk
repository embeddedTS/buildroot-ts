################################################################################
#
# ts4900-utils
#
################################################################################

TS4900_UTILS_AUTORECONF = YES
TS4900_UTILS_VERSION = 0e8087240f8f99cc0d1d74ec6f090f691d0cfdd8
TS4900_UTILS_SITE = $(call github,embeddedTS,ts4900-utils,$(TS4900_UTILS_VERSION))

$(eval $(autotools-package))
