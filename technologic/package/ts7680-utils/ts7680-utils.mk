################################################################################
#
# ts7680-utils
#
################################################################################

TS7680_UTILS_AUTORECONF = YES
TS7680_UTILS_VERSION = e5602d9ffe2d1d21e4da83f5957715809438e88e
TS7680_UTILS_SITE = $(call github,embeddedarm,ts7680-utils,$(TS7680_UTILS_VERSION))

$(eval $(autotools-package))
