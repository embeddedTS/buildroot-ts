# embeddedTS Buildroot
This repository is implemented as a BR2\_EXTERNAL based custom repository for embeddedTS products supporting Buildroot. Currently this includes support for:

* TS-4100
* TS-4300
* TS-4900
* TS-7100
* TS-7180
* TS-7250-V3
* TS-7400-V2
* TS-7553-V2
* TS-7670
* TS-7680
* TS-7800-V2
* TS-7970
* TS-9370
* TS-9390
* TS-TPC-7970


## Getting Started

This project implements a tagged release from upstream Buildroot as a submodule. This allows for this project to be used as it is to build whole Buildroot projects, or it can be integrated as a BR2\_EXTERNAL directory for custom implementations.


### Buildroot Manual

Users should familiarize themselves with the main [Buildroot manual](https://buildroot.org/downloads/manual/manual.html) and build workflow. The Buildroot manual covers system requirements, build flows, and a quick start.

This repoistory is configured as a BR2\_EXTERNAL tree that includes Buildroot as a submodule. The [Buildroot manual](https://buildroot.org/downloads/manual/manual.html) covers this concept in more detail.


### Cloning this Repository and its Submodule

The repository and the Buildroot submodule can all be cloned in a single command with:

	git clone --recurse-submodules https://github.com/embeddedTS/buildroot-ts.git
	cd buildroot-ts

From here, projects can be built, for example, this will generate a minimal TS-7250-V3 image:

	make ts7250v3_defconfig all

The output files will be located in `buildroot/output/images/`

As this uses Buildroot as a git submodule, its possible to change which branch/tag is used by Buildroot. For example, to checkout a specific tag:

	cd buildroot
	git checkout <tag>
	cd ..
	make <defconfig>
	make

This will output a Buildroot image built from the specified tag. The buildroot version can be reverted with the same init command used above:

	git submodule update --init

We will update the Buildroot release tag used as time goes on, we will only push these updates to the repository once they have been tested by us to ensure compatibility.


### Nested BR2\_EXTERNAL trees

The BR2\_EXTERNAL tree can be nested. This repository can be included as a submodule in a different repository with additional customizations added on top. See the [Buildroot manual](https://buildroot.org/downloads/manual/manual.html#outside-br-custom) for more information on this, as well as our demo projects which nest this repository:

- [TS-4100 Environmental Monitor Daughter Card](https://github.com/embeddedTS/ts4100-environ-dc)
- [TS-7970 Grid-EYE Demo](https://github.com/embeddedTS/ts7970-grid-eye-demo)


## Build instructions

| Product | Buildroot base defconfig | USB Image Replicator | Specialty |
|---------|--------------------------|----------------------|-----------|
| TS-4100 | [ts4100_defconfig](#ts4100_defconfig) | [tsimx6ul_usbprod_defconfig](#tsimx6ul_usbprod_defconfig) ||
| TS-4300 | [tsimx9_defconfig](#tsimx9_defconfig) | [tsimx9_usbprod_defconfig](#tsimx9_usbprod_defconfig) ||
| TS-4900 | [tsimx6_defconfig](#tsimx6_defconfig) | [tsimx6_usbprod_defconfig](#tsimx6_usbprod_defconfig) | [tsimx6_graphical_defconfig](#tsimx6_graphical_defconfig) |
| TS-7100 | [ts7100_defconfig](#ts7100_defconfig) | [ts7100_usbprod_defconfig](#ts7100_usbprod_defconfig) | |
| TS-7180 | [ts7180_defconfig](#ts7180_defconfig) | [ts7180_usbprod_defconfig](#ts7180_usbprod_defconfig) | |
| TS-7250-V3 | [ts7250v3_defconfig](#ts7250v3_defconfig) | [ts7250v3_usbprod_defconfig](#ts7250v3_usbprod_defconfig)  ||
| TS-7400-V2| [ts7400v2_defconfig](#ts7400v2_defconfig) | [tsimx28_usbprod_defconfig](#tsimx28_usbprod_defconfig) ||
| TS-7553-V2 | [ts7553v2_defconfig](#ts7553v2_defconfig) | [tsimx6ul_usbprod_defconfig](#tsimx6ul_usbprod_defconfig) ||
| TS-7670 | [ts7670_defconfig](#ts7670_defconfig) | [tsimx28_usbprod_defconfig](#tsimx28_usbprod_defconfig) ||
| TS-7680 | [ts7680_defconfig](#ts7680_defconfig) |  ||
| TS-7800-V2 | [ts7800v2_defconfig](#ts7800v2_defconfig) | [ts7800v2_usbprod_defconfig](#ts7800v2_usbprod_defconfig)  ||
| TS-7970 | [tsimx6_defconfig](#tsimx6_defconfig) | [tsimx6_usbprod_defconfig](#tsimx6_usbprod_defconfig) | [tsimx6_graphical_defconfig](#tsimx6_graphical_defconfig) |
| TS-9370 | [tsimx9_defconfig](#tsimx9_defconfig) | [tsimx9_usbprod_defconfig](#tsimx9_usbprod_defconfig) ||
| TS-9390 | [tsimx9_defconfig](#tsimx9_defconfig) | [tsimx9_usbprod_defconfig](#tsimx9_usbprod_defconfig) ||
| TS-TPC-7990 | [tsimx6_defconfig](#tsimx6_defconfig) | [tsimx6_usbprod_defconfig](#tsimx6_usbprod_defconfig) | [tsimx6_graphical_defconfig](#tsimx6_graphical_defconfig) |

All Buildroot base defconfigs above are compatible with the [Extra Packages defconfig fragment](#extra-packages).


### ts4100_defconfig
* Supports TS-4100 devices
* Generates a minimal Linux with hardware support
* Outputs `rootfs.tar.xz` which can be written to any boot device for the platform: USB, SD, eMMC, etc.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts4100_defconfig all

### ts7100_defconfig
* Supports TS-7100 devices
* Generates a minimal Linux with hardware support
* Outputs `rootfs.tar.xz` which can be written to any boot device for the platform: USB, eMMC.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7100_defconfig all

### ts7100_usbprod_defconfig
* Supports TS-7100 devices
* Able to capture disk images and/or write out disk images to all supported media on devices
* Outputs `ts7100-usb-image-replicator-rootfs.tar.xz` and `ts7100-usb-image-replicator.dd.xz` that can be written to a USB drive and booted on supported devices
* The `ts71000-usb-image-replicator.dd.xz` file is self expanding after first boot. It is intended to make the image capture process easier
* See the respective product manual for more information on the Image Replicator tool

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7100_usbprod_defconfig all

### ts7180_defconfig
* Supports TS-7180 devices
* Generates a minimal Linux with hardware support
* Outputs `rootfs.tar.xz` which can be written to any boot device for the platform: USB, eMMC.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7180_defconfig all

### ts7180_usbprod_defconfig
* Supports TS-7180 devices
* Able to capture disk images and/or write out disk images to all supported media on devices
* Outputs `ts7180-usb-image-replicator-rootfs.tar.xz` and `ts7180-usb-image-replicator.dd.xz` that can be written to a USB drive and booted on supported devices
* The `ts71800-usb-image-replicator.dd.xz` file is self expanding after first boot. It is intended to make the image capture process easier
* See the respective product manual for more information on the Image Replicator tool

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7180_usbprod_defconfig all

### ts7250v3_defconfig
* Supports TS-7250-V3 devices
* Generates a minimal Linux with hardware support
* Outputs `rootfs.tar.xz` which can be written to any boot device for the platform: USB, eMMC, etc.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7250v3_defconfig all

 ### ts7250v3_usbprod_defconfig
* Supports TS-7250-V3 devices
* Able to capture disk images and/or write out disk images to all supported media on devices
* Outputs `ts7250v3-usb-image-replicator-rootfs.tar.xz` and `ts7250v3-usb-image-replicator.dd.xz` that can be written to a USB drive and booted on supported devices
* The `ts7250v3-usb-image-replicator.dd.xz` file is self expanding after first boot. It is intended to make the image capture process easier
* See the respective product manual for more information on the Image Replicator tool

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7250v3_usbprod_defconfig all

### ts7400v2_defconfig
* Supports TS-7400-V2 devices with PCB revision B or newer
* Generates a minimal Linux with hardware support
* Outputs `sdcard.img` which can be written to to SD or eMMC on the device.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7400v2_defconfig all

### ts7553v2_defconfig
* Supports TS-7553-V2 devices
* Generates a minimal Linux with hardware support
* Outputs `rootfs.tar.xz` which can be written to any boot device for the platform: USB, SD, eMMC, etc.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7553v2_defconfig all

### ts7670_defconfig
* Supports TS-7670 devices with PCB revision D or newer
* Generates a minimal Linux with hardware support
* Outputs `sdcard.img` which can be written to to SD or eMMC on the device.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7670_defconfig all

### ts7680_defconfig
* Supports TS-7680 devices
* Upstream support provided by Buildroot, configuration file not directly in this repository
* This repository provides the following useful configuration options not in upstream Buildroot (be sure to enable them if desired):
	* BR2_PACKAGE_TS7680_UTILS (Utilities for TS-7680, `tshwctl`, `switchctl`, `tsmicroctl`, etc.)
	* BR2_PACKAGE_TSSILOMON_INIT (Enables TS-SILO script to run on startup)
 * Outputs `rootfs.tar` and `sdcard.img` which can be written to any boot device for the platform: USB, SD, eMMC, etc.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7680_defconfig all

### ts7800v2_defconfig
* Supports TS-7800-V2 devices
* Generates a minimal Linux with hardware support
* Outputs `rootfs.tar.xz` which can be written to any boot device for the platform: USB, eMMC, SATA, NFS, etc.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7800v2_defconfig all

### ts7800v2_usbprod_defconfig
* Image Replication tool for the TS-7800-V2
* Able to capture disk images and/or write out disk images to all supported media on devices
* Outputs `ts7800v2-usb-image-replicator-rootfs.tar.xz` and `ts7800v2-usb-image-replicator.dd.xz` that can be written to a USB drive and booted on supported devices
* The `ts7800v2-usb-image-replicator.dd.xz` file is self expanding after first boot. It is intended to make the image capture process easier
* See the respective product manual for more information on the Image Replicator tool

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make ts7800v2_usbprod_defconfig all

### tsimx28_usbprod_defconfig
* Image Replication tool for TS-7670 and TS-7400-V2 device
* Able to capture disk images and/or write out disk images to all supported media on devices. :warning: ***Not possible in all situations, see 'tsimx28 notes' below***
* Outputs `tsimx28-usb-image-replicator-rootfs.tar.xz` and `tsimx28-usb-image-replicator.dd.xz` that can be written to a USB drive and booted on supported devices
* The `tsimx28-usb-image-replicator.dd.xz` file is self expanding after first boot. It is intended to make the image capture process easier
* See the respective product manual for more information on the Image Replicator tool

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make tsimx28_usbprod_defconfig all

#### tsimx28 notes
* Compatible with stock images as well as our additional supported images, e.g. Linux kernel 4.9 with Debian Stretch.
* i.MX28 based platforms require a whole disk image to be written through the Image Replicator tool to create a bootable media. This is a limitation of the platforms themselves needing a bootloader present on the boot media. If the goal is to update a few files or unpack a tarball, it is recommended to use the stock initramfs scripting process, e.g. [https://docs.embeddedts.com/TS-7670#Scripting_in_the_initramfs](https://docs.embeddedts.com/TS-7670#Scripting_in_the_initramfs)
* The Image Replicator tool is **not** compatible with devices that have soldered down NAND flash. Contact our [support team](https://support.embeddedts.com/support/home) if you are working with an older device that uses soldered down NAND flash rather than eMMC.

Devices that are compatible with this Image Replicator tool boot directly to the selected media, SD or eMMC, and are unable to load a kernel from a USB disk.

When booted from a stock image, a shim script is used to install U-Boot over top of the bootloader provided by NXP on the booted media (SD / eMMC) and then the unit is rebooted and the Image Replication process starts. In other words, the Image Replicator tool, booted on compatible platforms, will modify booted media!

This is not an issue for the most common use-case of writing custom images to devices. For example, a TS-7670 ordered from us will have eMMC pre-programmed with our stock image. It would be possible with the Image Replicator USB drive inserted, for the unit to boot, install a U-Boot bootloader to the eMMC flash, reboot itself, and start the Image Replicator process to write out full custom images to eMMC or to attached microSD cards. Image Capture of a stock image with this tool is difficult due to the process required to boot the Image Replicator. Please contact our [support team](https://support.embeddedts.com/support/home) for assistance if you need to run this process.

### tsimx6_defconfig
* Supports TS-4900, TS-7970, and TS-TPC-7990 devices
* Generates a minimal Linux with hardware support
* Outputs `rootfs.tar.xz` which can be written to any boot device for the platform: USB, eMMC, SATA, NFS, etc.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make tsimx6_defconfig all

### tsimx6_graphical_defconfig
* Supports TS-4900, TS-7970, and TS-TPC-7990 devices
* Generates an example image focused on showcasing the graphical abilities of the i.MX6 CPU
* Boots to Weston with Wayland/Xwayland support and includes Weston/Wayland demos. Provides Qt5 demos utilizing OpenGLES with a Wayland wrapper taking advantage of the Vivante GPU. Provides a video player able to take advantage of VPU hardware.
* Outputs `rootfs.tar.xz` which can be written to any boot device for the platform: USB, eMMC, SATA, NFS, etc.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make tsimx6_graphical_defconfig xcb-util-cursor all
    # There is a bug in Weston in Buildroot that requires xcb-util-cursor explicitly
    # built first.

### tsimx6_usbprod_defconfig
* Image Replication tool for TS-4900, TS-7970, and TS-TPC-7990 devices
* Able to capture disk images and/or write out disk images to all supported media on devices
* Outputs `tsimx6-usb-image-replicator-rootfs.tar.xz` and `tsimx6-usb-image-replicator.dd.xz` that can be written to a USB drive and booted on supported devices
* The `tsimx6-usb-image-replicator.dd.xz` file is self expanding after first boot. It is intended to make the image capture process easier
* See the respective product manual for more information on the Image Replicator tool

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make tsimx6_usbprod_defconfig all

### tsimx6ul_usbprod_defconfig
* Image Replication tool for TS-4100 and TS-7553-V2 devices
* Able to capture disk images and/or write out disk images to all supported media on devices
* Outputs `tsimx6ul-usb-image-replicator-rootfs.tar.xz` and `tsimx6ul-usb-image-replicator.dd.xz` that can be written to a USB drive and booted on supported devices
* The `tsimx6ul-usb-image-replicator.dd.xz` file is self expanding after first boot. It is intended to make the image capture process easier
* See the respective product manual for more information on the Image Replicator tool

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make tsimx6ul_usbprod_defconfig all

### tsimx9_defconfig
* Supports TS-4300, TS-9370, and TS-9390 devices
* Generates a minimal Linux with hardware support
* Outputs `rootfs.tar.xz` which can be written to any boot device for the platform: USB, eMMC, NFS, etc.

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make tsimx9_defconfig all

### tsimx9_usbprod_defconfig
* Image Replication tool for TS-4300, TS-9370, and TS-9390 devices
* Able to capture disk images and/or write out disk images to all supported media on devices
* Outputs `tsimx9-usb-image-replicator-rootfs.tar.xz` and `tsimx9-usb-image-replicator.dd.xz` that can be written to a USB drive and booted on supported devices
* The `tsimx9-usb-image-replicator.dd.xz` file is self expanding after first boot. It is intended to make the image capture process easier
* See the respective product manual for more information on the Image Replicator tool

Can be built with (See [Using Docker](#using-docker) for how to build in Docker container):

	make tsimx9_usbprod_defconfig all

## Extra Packages

The platform defconfig files are very basic configurations; providing support for the base hardware with no additional tools. We've created an `extra_packages_defconfig` that can be merged with any of the above defconfig files to provide additional packages that are more in-line with the stock images for our devices.

Buildroot itself provides a script to merge and make the config file. Rather than running any of the above `make <platform>_defconfig` commands, instead run the merge script. For example, here is how to build the extra packages config for the TS-7553-V2:

    ./buildroot/support/kconfig/merge_config.sh technologic/configs/extra_packages_defconfig technologic/configs/ts7553v2_defconfig
    make

Simply substitute out the platform defconfig for other devices. Note that each defconfig provided to the script overrides any values set in the previous defconfig if they conflict. It is recommended to pass the extra_packages_defconfig before the device defconfig so any conflicts result in favoring the known base configuration file.


## Using Docker
Optionally, configurations can be build inside of a Docker container. The container is maintained by Buildroot as part of their CI scripts, however, it can be used as a general purpose build environment as well.

See the [Buildroot manual](https://buildroot.org/downloads/manual/manual.html#adding-board-support) for details on using their provided container for a customized Docker file if needed.

The container is a script that can be directly entered, or, if arguments are passed to the script, they are run inside the container. The first time the script is run, it will build the container to this may take additional time.

If nesting this repository as a submodule inside of another BR2\_EXTERNAL tree, the container can be called in the same way from the root of the top-level BR2\_EXTERNAL tree.

For example, to use the TS-7250-V3 defconfig, open a menuconfig window, then start a build after saving any changes:

    ./buildroot/utils/docker-run make ts7250v3_defconfig menuconfig all

Build the Image Replicator tool for a TS-4100/TS-7553-V2 with multiple commands:

    ./buildroot/utils/docker-run make clean
    ./buildroot/utils/docker-run make tsimx6ul_usbprod_defconfig
    ./buildroot/utils/docker-run make

It is also possible to enter a shell inside of the container:

    ./buildroot/utils/docker-run

From there, any commands issued would be issued inside of the container. See notes below for more details.

### Notes on using Docker

* Choose building either from the host workstation or Docker container, it is not recommended to mix and match. Do a `make clean` from one build system in order to be able to cleanly switch to another. Switching between the two without `make clean` in between will likely cause build issues
* The `pwd` is bind mounted to the same directory path inside the container, with `$HOME` being set to `/home/br-user/`. Any changes made inside of `pwd` in the container will be retained, any changes to the rest of the container filesystem will be lost once the container is exited
