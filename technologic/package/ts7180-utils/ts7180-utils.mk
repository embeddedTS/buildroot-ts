################################################################################
#
# ts7180-utils
#
################################################################################

TS7180_UTILS_AUTORECONF = YES
TS7180_UTILS_VERSION = f4827ab4a3f3c1f5f555de57af05168300892bb3
TS7180_UTILS_SITE = $(call github,embeddedTS,ts7180-utils,$(TS7180_UTILS_VERSION))

$(eval $(autotools-package))
