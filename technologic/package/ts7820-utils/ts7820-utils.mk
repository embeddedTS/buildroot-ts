################################################################################
#
# ts7820-utils
#
################################################################################

TS7820_UTILS_AUTORECONF = YES
TS7820_UTILS_VERSION = e4769fd19f4f09170e2b7d11ced1d37e8d7bc52f
TS7820_UTILS_SITE = $(call github,embeddedTS,ts7820-utils,$(TS7820_UTILS_VERSION))

$(eval $(autotools-package))
