################################################################################
#
# ts7670-utils-linux4.x
#
################################################################################

TS7670_UTILS_LINUX4X_AUTORECONF = YES
TS7670_UTILS_LINUX4X_VERSION = e80541cd1a366b49752ae6018ad773ed5da03630
TS7670_UTILS_LINUX4X_SITE = $(call github,embeddedTS,ts7670-utils-linux4.x,$(TS7670_UTILS_LINUX4X_VERSION))

$(eval $(autotools-package))
