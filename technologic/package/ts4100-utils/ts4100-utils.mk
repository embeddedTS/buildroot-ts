################################################################################
#
# ts4100-utils
#
################################################################################

TS4100_UTILS_AUTORECONF = YES
TS4100_UTILS_VERSION = 6249d98466e6f7963f8f7ef257aa9550a00402fc
TS4100_UTILS_SITE = $(call github,embeddedTS,ts4100-utils,$(TS4100_UTILS_VERSION))

$(eval $(autotools-package))
