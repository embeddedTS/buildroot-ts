export BR2_EXTERNAL ?= $(realpath technologic)
export BR2_GLOBAL_PATCH_DIR ?= $(realpath technologic)

.DEFAULT_GOAL := all

%:
	$(MAKE) -C buildroot $@
