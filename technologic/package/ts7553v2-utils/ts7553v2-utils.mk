################################################################################
#
# ts7553v2-utils
#
################################################################################

TS7553V2_UTILS_AUTORECONF = YES
TS7553V2_UTILS_VERSION = 975eebed26d0fa507db9a0c5e2735434985f8d70
TS7553V2_UTILS_SITE = $(call github,embeddedTS,ts7553v2-utils,$(TS7553V2_UTILS_VERSION))

$(eval $(autotools-package))
