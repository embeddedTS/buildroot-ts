################################################################################
#
# ts7100-utils
#
################################################################################

TS7100_UTILS_AUTORECONF = YES
TS7100_UTILS_VERSION = 139b68719ae83bf22f2e10f8aa6f35751327ba9f
TS7100_UTILS_SITE = $(call github,embeddedTS,ts7100-utils,$(TS7100_UTILS_VERSION))

$(eval $(autotools-package))
