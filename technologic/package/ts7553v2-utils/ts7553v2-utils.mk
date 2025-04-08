################################################################################
#
# ts7553v2-utils
#
################################################################################

TS7553V2_UTILS_AUTORECONF = YES
TS7553V2_UTILS_VERSION = v2.0.1
TS7553V2_UTILS_SITE = $(call github,embeddedTS,ts7553v2-utils,$(TS7553V2_UTILS_VERSION))
TS7553V2_UTILS_DEPENDENCIES = cairo
TS7553V2_UTILS_LICENSE = BSD-2-Clause
TS7553V2_UTILS_LICENSE_FILES = LICENSE

$(eval $(autotools-package))
