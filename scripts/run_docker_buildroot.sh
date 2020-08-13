#!/bin/bash -ex

if [ $(id -u) -eq 0 ]; then
	set +x
	echo ""
	echo "This script should not be run as root!"
	echo ""
	echo "Run this script again as a normal user. Note that the buildroot-ts/"
	echo "directory should be owned by the same user (or have adequate"
	echo "permissions) that is running this Docker container build script!"
	echo ""
	exit 1;
fi


docker build --quiet --tag "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" docker/

# build must run as a normal user
# Overwrite $HOME to allow for buildroot ccache to work somewhat seamlessly
docker run --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" $@
