################################################################################
#
# ts4900-utils
#
################################################################################

TS4900_UTILS_AUTORECONF = YES
TS4900_UTILS_VERSION = 84a2bac6d32e9a0d40eee964dac40893f6467bd1
TS4900_UTILS_SITE = $(call github,embeddedTS,ts4900-utils,$(TS4900_UTILS_VERSION))

$(eval $(autotools-package))
