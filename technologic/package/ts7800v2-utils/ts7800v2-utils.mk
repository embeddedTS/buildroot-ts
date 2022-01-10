################################################################################
#
# ts7800v2-utils
#
################################################################################

TS7800V2_UTILS_AUTORECONF = YES
TS7800V2_UTILS_VERSION = ff4bb01bc18111805f586a9fd1d9844d723894d2
TS7800V2_UTILS_SITE = $(call github,embeddedTS,ts7800v2-utils,$(TS7800V2_UTILS_VERSION))

$(eval $(autotools-package))
