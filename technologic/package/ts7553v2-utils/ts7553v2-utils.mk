################################################################################
#
# ts7553v2-utils
#
################################################################################

TS7553V2_UTILS_AUTORECONF = YES
TS7553V2_UTILS_VERSION = 28ffedde5a4e08ec6cb81dd9b753beb4ee733dcc
TS7553V2_UTILS_SITE = $(call github,embeddedarm,ts7553v2-utils,$(TS7553V2_UTILS_VERSION))

$(eval $(autotools-package))
