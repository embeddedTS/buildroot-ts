################################################################################
#
# ts7680-utils
#
################################################################################

TS7680_UTILS_AUTORECONF = YES
TS7680_UTILS_VERSION = c335b569b2ee654870c6ee04af280bdc61f8f8a4
TS7680_UTILS_SITE = $(call github,embeddedTS,ts7680-utils,$(TS7680_UTILS_VERSION))

$(eval $(autotools-package))
