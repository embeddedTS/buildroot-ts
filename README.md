
# Technologic Systems Buildroot

This branch implements BR_EXTERNAL for Technologic systems products.  Currently this includes:

* TS-7250-V3
* TS-7100
* TS-7553-V2

This supports these defconfigs:
* make ts7250v3_usbprod_defconfig
	* Supports TS-7250-V3 and TS-7100
	* Generates a tar for use on a thumbdrive that runs a blast.sh script on the drive to rewrite and verify the media on the board.
	* Outputs to buildroot/output/images/ts7250v3-usb-production-rootfs.tar.bz2
	* Extract this to a USB drive with one partition, and a partition of either ext2/3/4 or fat32.
* make ts7250v3_defconfig
	* Supports TS-7250-V3 and TS-7100
	* Generates a minimal Linux with hardware support
	* Write to any boot device for the board, USB, eMMC
* make ts7553v2_defconfig
	* Supports TS-7553-V2
	* Generates a minimal Linux with hardware support (based on 4.9 kernel)
	* Write to any boot device for the unit: USB, SD, eMMC, NFS, etc.


For example, this will generate a minimal TS-7250-V3 image:

    git clone https://github.com/embeddedarm/buildroot-ts.git
    cd buildroot-ts
    git submodule update --init
    make ts7250v3_defconfig
    make

The output files will be located in `buildroot/output/images/`


As this uses Buildroot as a git submodule, its possible to change which branch/tag is used by Buildroot. For example, to checkout a specific tag:

    cd buildroot
    git checkout <tag>
    cd ..
    make <defconfig>
    make

This will output a Buildroot image built from the specified tag. The buildroot version can be reverted with the same init command used above:

    git submodule update --init
