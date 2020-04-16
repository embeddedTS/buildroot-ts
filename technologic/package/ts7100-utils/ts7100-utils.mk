################################################################################
#
# ts7100-utils
#
################################################################################

TS7100_UTILS_AUTORECONF = YES
TS7100_UTILS_VERSION = 0ac22280ccef24de350dd12d40a3cb7b5c974180
TS7100_UTILS_SITE = $(call github,embeddedarm,ts7100-utils,$(TS7100_UTILS_VERSION))

$(eval $(autotools-package))
