################################################################################
#
# ts7400v2-utils-linux4.x
#
################################################################################

TS7400V2_UTILS_LINUX4X_AUTORECONF = YES
TS7400V2_UTILS_LINUX4X_VERSION = d2494453fac598adfe3be543ba22aa646f10c292
TS7400V2_UTILS_LINUX4X_SITE = $(call github,embeddedTS,ts7400v2-utils-linux4.x,$(TS7400V2_UTILS_LINUX4X_VERSION))

$(eval $(autotools-package))
