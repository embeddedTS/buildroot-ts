#!/bin/bash -e

# XXX: Must be run from root dir of buildroot-ts tree!

usage() {
	set +x
	echo ""
	echo "Usage:"
	echo "./build-all-configs.sh [group]"
	echo ""
	echo "[group] is one of:"
	echo "  base    - Build only the base platform configs"
	echo "  extra   - Build only the base w/ extra_packages configs"
	echo "  usbprod - Build only the Image Replicator configs"
	echo ""
	echo "If no [group] is specified, all configurations will be built in parallel!"
	echo ""
	exit 1;
}


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

if [ "$1" == "-h" ]; then
	usage
fi

# Build array of total builds
# This should include all base builds, usbprod, and extra_package builds
USBPROD=()
BASE=()
EXTRA=()
for CONFIG in technologic/configs/ts*usbprod*; do
	CONFIG="$(basename ${CONFIG})"
	USBPROD+=("${CONFIG}")
done

for CONFIG in technologic/configs/ts*; do
	CONFIG="$(basename ${CONFIG})"
	BOARD="${CONFIG%_*}"
	if [[ "${BOARD}" == *"usbprod" ]]; then continue; fi
	BASE+=("${CONFIG}")
	EXTRA+=("${CONFIG}")
done

# Build list of total configurations. If no args supplied, build all
if [ $# -ne 1 ]; then
	TOTAL=$((${#USBPROD[@]} + ${#BASE[@]} + ${#EXTRA[@]}))
elif [ "$1" == "base" ]; then
	echo "Building only base configurations!"
	TOTAL=$((${#BASE[@]}))
	EXTRA=()
	USBPROD=()
elif [ "$1" == "extra" ]; then
	echo "Building only base w/ extra_packages configurations!"
	TOTAL=$((${#EXTRA[@]}))
	BASE=()
	USBPROD=()
elif [ "$1" == "usbprod" ]; then
	echo "Building only Image Replicator configurations!"
	TOTAL=$((${#USBPROD[@]}))
	BASE=()
	EXTRA=()
else
	echo "Unknown argument \"$1\""
	usage
fi

# Across all builds, we do not want to use more than $(nproc) CPUs,
# but we need to make sure that every build has at least one CPU
# it can build on.
NPROC=$(nproc)
# bash does floor rounding by default
PER_PROC=$((${NPROC}/${TOTAL}))
if [ ${PER_PROC} -eq 0 ]; then
	PER_PROC=1
fi

echo "WARNING! This will start ${TOTAL} parallel builds, each build using up to ${PER_PROC} CPUs!"
echo "A potential load of $((${PER_PROC}*${TOTAL})).00!"
echo "Press ctrl+c to stop this within 10 seconds"
sleep 10

echo "Building docker container"
docker build --quiet --tag "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" docker/
echo "Starting builds"

unset DOCKER_PIDS
for CONFIG in ${USBPROD[@]}; do
	BOARD=${CONFIG%_*}
	mkdir -p "out/${BOARD}"

	# Set up config file
	ARG="O=/work/out/${BOARD} ${CONFIG}"
	DOCKER_PID=$(docker run --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" bash -c "make ${ARG} >/work/out/"${BOARD}"/log 2>&1")
	DOCKER_PIDS="${DOCKER_PID} ${DOCKER_PIDS}"

	# Modify the config file to use set number of CPUs max
	ARG="./buildroot/utils/config --file /work/out/${BOARD}/.config --set-val BR2_JLEVEL ${PER_PROC}"
	DOCKER_PID=$(docker run --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" bash -c "${ARG} >/work/out/"${BOARD}"/log 2>&1")
	DOCKER_PIDS="${DOCKER_PID} ${DOCKER_PIDS}"

	# Start the build
	ARG="O=/work/out/${BOARD} all"
	DOCKER_PID=$(docker run -d --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" bash -c "make ${ARG} >/work/out/"${BOARD}"/log 2>&1")
	DOCKER_PIDS="${DOCKER_PID} ${DOCKER_PIDS}"
done

for CONFIG in ${BASE[@]}; do
	BOARD=${CONFIG%_*}
	mkdir -p "out/${BOARD}"

	# Set up config file
	ARG="O=/work/out/${BOARD} ${CONFIG}"
	DOCKER_PID=$(docker run --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" bash -c "make ${ARG} >/work/out/"${BOARD}"/log 2>&1")
	DOCKER_PIDS="${DOCKER_PID} ${DOCKER_PIDS}"

	# Modify the config file to use set number of CPUs max
	ARG="./buildroot/utils/config --file /work/out/${BOARD}/.config --set-val BR2_JLEVEL ${PER_PROC}"
	DOCKER_PID=$(docker run --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" bash -c "${ARG} >/work/out/"${BOARD}"/log 2>&1")
	DOCKER_PIDS="${DOCKER_PID} ${DOCKER_PIDS}"

	# Start the build
	ARG="O=/work/out/${BOARD} all"
	DOCKER_PID=$(docker run -d --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" bash -c "make ${ARG} >/work/out/"${BOARD}"/log 2>&1")
	DOCKER_PIDS="${DOCKER_PID} ${DOCKER_PIDS}"
done

for CONFIG in ${EXTRA[@]}; do
	BOARD=${CONFIG%_*}
	BOARD="${BOARD}_extra_packages"
	mkdir -p "out/${BOARD}"

	# Make the merged defconfig
	ARG="./buildroot/support/kconfig/merge_config.sh -O /work/out/${BOARD}/ technologic/configs/extra_packages_defconfig technologic/configs/${CONFIG}"
	DOCKER_PID=$(docker run --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" bash -c "${ARG} >/work/out/"${BOARD}"/log 2>&1")
	DOCKER_PIDS="${DOCKER_PID} ${DOCKER_PIDS}"

	# Modify the config file to use set number of CPUs max
	ARG="./buildroot/utils/config --file /work/out/${BOARD}/.config --set-val BR2_JLEVEL ${PER_PROC}"
	DOCKER_PID=$(docker run --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" bash -c "${ARG} >/work/out/"${BOARD}"/log 2>&1")
	DOCKER_PIDS="${DOCKER_PID} ${DOCKER_PIDS}"

	# Start the build
	ARG="O=/work/out/${BOARD} all"
	DOCKER_PID=$(docker run -d --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" bash -c "make ${ARG} >/work/out/"${BOARD}"/log 2>&1")
	DOCKER_PIDS="${DOCKER_PID} ${DOCKER_PIDS}"
done

echo ""
echo ""
echo ""
echo "All builds running!"
echo ""
echo "Waiting until all containers/builds have completed"
echo ""
echo "It is safe to ctrl+c out of this, builds are running in the background."
echo "Logs for each build can be found in ./out/<CONFIG>/log"
echo "All containers/builds can be stopped with 'docker kill \$(docker ps -q)'"
echo ""
echo ""
echo ""
docker wait ${DOCKER_PIDS}


