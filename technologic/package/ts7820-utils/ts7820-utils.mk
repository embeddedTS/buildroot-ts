################################################################################
#
# ts7820-utils
#
################################################################################

TS7820_UTILS_AUTORECONF = YES
TS7820_UTILS_VERSION = ce635c5196a727d847a8d7d8c25aaf588346dee4
TS7820_UTILS_SITE = $(call github,embeddedarm,ts7820-utils,$(TS7820_UTILS_VERSION))

$(eval $(autotools-package))
