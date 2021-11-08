################################################################################
#
# ts7100-utils
#
################################################################################

TS7100_UTILS_AUTORECONF = YES
TS7100_UTILS_VERSION = 0105b4739338c58164b0e5c4535db9d4f1340bc1
TS7100_UTILS_SITE = $(call github,embeddedarm,ts7100-utils,$(TS7100_UTILS_VERSION))

$(eval $(autotools-package))
