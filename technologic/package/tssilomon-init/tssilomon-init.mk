################################################################################
#
# TS-SILO tssilmon monitor daemon startup script
#
################################################################################

define TSSILOMON_INIT_INSTALL_INIT_SYSV
        $(INSTALL) -D -m 755 \
	  $(BR2_EXTERNAL_TECHNOLOGIC_PATH)/package/tssilomon-init/S99tssilomon \
          $(TARGET_DIR)/etc/init.d/S99tssilomon
endef

$(eval $(generic-package))
