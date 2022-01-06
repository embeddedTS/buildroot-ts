################################################################################
#
# ts7800v2-utils
#
################################################################################

TS7800V2_UTILS_AUTORECONF = YES
TS7800V2_UTILS_VERSION = ae1740a3ada41467f86ce7b5b0f8b5972e9bacf6
TS7800V2_UTILS_SITE = $(call github,embeddedTS,ts7800v2-utils,$(TS7800V2_UTILS_VERSION))

$(eval $(autotools-package))
