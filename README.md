
# Technologic Systems Buildroot

## Build instructions
This branch implements BR_EXTERNAL for Technologic systems products.  Currently this includes:

* TS-4100
* TS-7100 (via ts7250v3_defconfig)
* TS-7250-V3
* TS-7553-V2

This supports these defconfigs:
* make ts4100_defconfig
	* Supports TS-4100
	* Generates a minimal Linux with hardware support (based on 4.9 kernel)
	* Write to any boot device for the unit: USB, SD, eMMC, NFS, etc.
* make ts7250v3_defconfig
	* Supports TS-7250-V3 and TS-7100
	* Generates a minimal Linux with hardware support
	* Write to any boot device for the board, USB, eMMC
* make ts7553v2_defconfig
	* Supports TS-7553-V2
	* Generates a minimal Linux with hardware support (based on 4.9 kernel)
	* Write to any boot device for the unit: USB, SD, eMMC, NFS, etc.

The following defconfigs are used to create bootable USB drives meant for production:
* make ts7250v3_usbprod_defconfig
	* Supports TS-7250-V3 and TS-7100
	* Generates a tar for use on a thumbdrive that runs a blast.sh script on the drive to rewrite and verify the media on the board.
	* Outputs to buildroot/output/images/ts7250v3-usb-production-rootfs.tar.bz2
	* Extract this to a USB drive with one partition, and a partition of either ext2/3/4 or fat32.
* make tsimx6ul_usbprod_defconfig
	* Supports TS-4100 and TS-7553-V2
	* Generates a tar for use on a thumbdrive that runs a blast.sh script on the drive to rewrite and verify the media on the board. See the respective product manual for information on this Production Mechanism.
	* Outputs to buildroot/output/images/tsimx6ul-usb-production-rootfs.tar.bz2
	* Extract this to a USB drive with one partition, formatted either ext2/3/4 or fat32.


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

## Using Docker
Optionally, this can be built in a Docker container. The container is maintained in lock-step with this project and the upstream Buildroot submodule. Meaning it is possible to go back to a specific commit in history and get a valid environment for building in via Docker.

The container is implemented as a simple front-end script, any arguments passed to the script will be passed directly to the root `buildroot-ts/` directory inside of the container. The first time the script is run, it will build the container so this may take additional time.

For example, to use the TS-7250-V3 defconfig, open a menuconfig window, then start a build:

    ./scripts/run_docker_buildroot.sh make ts7250v3_defconfig
    ./scripts/run_docker_buildroot.sh make menuconfig
    ./scripts/run_docker_buildroot.sh make

### Notes on using Docker

* Choose building either from the host workstation or Docker container, it is not recommended to mix and match. Do a `make clean` from one build system in order to be able to cleanly switch to another. Switching between the two without `make clean` in between will likely cause build issues
* The `pwd` is mapped to `/work/` inside the container, with `$HOME` being set to `/work/`. Any changes made inside of `/work/` will be retained, any changes to the rest of the container filesystem will be lost once the container is exited
* Most of our configs have ccache enabled though Buildroot. Normally, this lies at `~/.buildroot-ccache`. Inside the container however, the `buildroot-ts/` directory is set to `$HOME`. If relying on ccache in Buildroot, be sure to continually use the same build system to prevent excessive work
* It's possible to enter the shell of the container by passing `bash` to the script, i.e. `./scripts/run_docker_buildroot.sh bash`
