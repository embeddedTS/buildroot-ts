################################################################################
#
# growpart script
#
################################################################################

# There are release tags but they have a forward slash (/) in them and
# I've not found a way to correctly download that
GROWPART_VERSION = bca751ee41499511512ea4c8cd593a0a60499d51
GROWPART_SITE = $(call github,canonical,cloud-utils,$(GROWPART_VERSION))

define GROWPART_INSTALL_TARGET_CMDS
	$(INSTALL) -m 0744 $(@D)/bin/growpart $(TARGET_DIR)/bin
endef

$(eval $(generic-package))
