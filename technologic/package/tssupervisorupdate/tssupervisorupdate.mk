################################################################################
#
# tssupervisorupdate
#
################################################################################

TSSUPERVISORUPDATE_VERSION = v1.1.1
TSSUPERVISORUPDATE_SITE = $(call github,embeddedTS,tssupervisorupdate,$(TSSUPERVISORUPDATE_VERSION))
TSSUPERVISORUPDATE_LICENSE = BSD-2-Clause
TSSUPERVISORUPDATE_LICENSE_FILES = LICENSE

$(eval $(meson-package))
