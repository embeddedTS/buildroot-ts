################################################################################
#
# ts7180-utils
#
################################################################################

TS7180_UTILS_AUTORECONF = YES
TS7180_UTILS_VERSION = 2b52a23c72e27d09fa660589af4dac1481891ad2
TS7180_UTILS_SITE = $(call github,embeddedTS,ts7180-utils,$(TS7180_UTILS_VERSION))

$(eval $(autotools-package))
