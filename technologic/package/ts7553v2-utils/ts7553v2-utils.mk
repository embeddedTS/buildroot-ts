################################################################################
#
# ts7553v2-utils
#
################################################################################

TS7553V2_UTILS_AUTORECONF = YES
TS7553V2_UTILS_VERSION = dceb5751e83d68eb233f62cbff69a49acdd756a6
TS7553V2_UTILS_SITE = $(call github,embeddedarm,ts7553v2-utils,$(TS7553V2_UTILS_VERSION))

$(eval $(autotools-package))
