################################################################################
#
# ts7400v2-utils-linux4.x
#
################################################################################

TS7400V2_UTILS_LINUX4X_AUTORECONF = YES
TS7400V2_UTILS_LINUX4X_VERSION = v1.0.1
TS7400V2_UTILS_LINUX4X_SITE = $(call github,embeddedTS,ts7400v2-utils-linux4.x,$(TS7400V2_UTILS_LINUX4X_VERSION))
TS7400V2_UTILS_LINUX4X_LICENSE = BSD-2-Clause
TS7400V2_UTILS_LINUX4X_LICENSE_FILES = LICENSE

$(eval $(autotools-package))
