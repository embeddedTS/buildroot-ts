################################################################################
#
# ts4100-utils
#
################################################################################

TS4100_UTILS_AUTORECONF = YES
TS4100_UTILS_VERSION = 78d155291cd61e215d121f57b4231d13be99a1f2
TS4100_UTILS_SITE = $(call github,embeddedTS,ts4100-utils,$(TS4100_UTILS_VERSION))

$(eval $(autotools-package))
