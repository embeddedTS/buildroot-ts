#!/bin/bash -e

# XXX: Must be run from root dir of buildroot-ts tree!

usage() {
	set +x
	echo ""
	echo "Usage:"
	echo "./build-all-configs.sh [group]"
	echo "./build-all-configs.sh clean"
	echo ""
	echo "[group] is one of:"
	echo "  base    - Build only the base platform configs"
	echo "  extra   - Build only the base w/ extra_packages configs"
	echo "  usbprod - Build only the Image Replicator configs"
	echo ""
	echo "If no [group] is specified, all configurations will be built in parallel!"
	echo "The clean command resets existing Buildroot outputs without building."
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

COMMAND="build"
if [ "${1:-}" == "clean" ]; then
	COMMAND="clean"
	shift
fi

if [ "${1:-}" == "-h" ] || [ "${1:-}" == "--help" ]; then
	usage
fi

if [ "$#" -gt 1 ]; then
	echo "Too many arguments"
	usage
fi

TOPDIR="$(pwd)"

if [ "${COMMAND}" == "clean" ]; then
	shopt -s nullglob
	OUTPUT_DIRS=(out/*/)

	if [ ${#OUTPUT_DIRS[@]} -eq 0 ]; then
		echo "No output directories found under out/"
		exit 0
	fi

	CLEAN_PIDS=()
	CLEAN_DIRS=()
	for OUTPUT_DIR in "${OUTPUT_DIRS[@]}"; do
		OUTPUT_DIR="${OUTPUT_DIR%/}"
		echo "${OUTPUT_DIR}: CLEANING"
		(
			./buildroot/utils/docker-run make "O=${TOPDIR}/${OUTPUT_DIR}" clean >>"${OUTPUT_DIR}/log" 2>&1
		) &
		CLEAN_PIDS+=("$!")
		CLEAN_DIRS+=("${OUTPUT_DIR}")
	done

	CLEAN_FAILED=0
	for INDEX in "${!CLEAN_PIDS[@]}"; do
		if ! wait "${CLEAN_PIDS[${INDEX}]}"; then
			echo "${CLEAN_DIRS[${INDEX}]}: CLEAN FAILED"
			CLEAN_FAILED=1
		fi
	done
	exit "${CLEAN_FAILED}"
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

# Build list of total configurations. If no group is supplied, build all.
if [ $# -eq 0 ]; then
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

echo "Starting builds"

BUILD_PIDS=()
# docker-run keeps stdin open for the container. Redirect it before
# backgrounding so Docker does not retain the terminal as a background job.
start_build() {
	local BOARD="$1"
	local CONFIG_NAME="${BOARD}_defconfig"

	echo "${CONFIG_NAME}: RUNNING"
	(
		if ./buildroot/utils/docker-run make "O=${TOPDIR}/out/${BOARD}" all </dev/null >>"out/${BOARD}/log" 2>&1; then
			echo "${CONFIG_NAME}: COMPLETED"
		else
			echo "${CONFIG_NAME}: FAILED"
			exit 1
		fi
	) &
	BUILD_PIDS+=("$!")
}

for CONFIG in ${USBPROD[@]}; do
	BOARD=${CONFIG%_*}
	mkdir -p "out/${BOARD}"

	# Set up config file
	./buildroot/utils/docker-run make "O=${TOPDIR}/out/${BOARD}" "${CONFIG}" >"out/${BOARD}/log" 2>&1

	# Modify the config file to use set number of CPUs max
	./buildroot/utils/docker-run ./buildroot/utils/config --file "${TOPDIR}/out/${BOARD}/.config" --set-val BR2_JLEVEL "${PER_PROC}" >>"out/${BOARD}/log" 2>&1

	# Start the build
	start_build "${BOARD}"
done

for CONFIG in ${BASE[@]}; do
	BOARD=${CONFIG%_*}
	mkdir -p "out/${BOARD}"

	# Set up config file
	./buildroot/utils/docker-run make "O=${TOPDIR}/out/${BOARD}" "${CONFIG}" >"out/${BOARD}/log" 2>&1

	# Modify the config file to use set number of CPUs max
	./buildroot/utils/docker-run ./buildroot/utils/config --file "${TOPDIR}/out/${BOARD}/.config" --set-val BR2_JLEVEL "${PER_PROC}" >>"out/${BOARD}/log" 2>&1

	# Start the build
	start_build "${BOARD}"
done

for CONFIG in ${EXTRA[@]}; do
	BOARD=${CONFIG%_*}
	BOARD="${BOARD}_extra_packages"
	mkdir -p "out/${BOARD}"

	# Make the merged defconfig
	./buildroot/utils/docker-run ./buildroot/support/kconfig/merge_config.sh -O "${TOPDIR}/out/${BOARD}/" technologic/configs/extra_packages_defconfig "technologic/configs/${CONFIG}" >"out/${BOARD}/log" 2>&1

	# Modify the config file to use set number of CPUs max
	./buildroot/utils/docker-run ./buildroot/utils/config --file "${TOPDIR}/out/${BOARD}/.config" --set-val BR2_JLEVEL "${PER_PROC}" >>"out/${BOARD}/log" 2>&1

	# Start the build
	start_build "${BOARD}"
done

echo ""
echo ""
echo ""
echo "All builds running!"
echo ""
echo "Waiting until all builds have completed"
echo ""
echo "Logs for each build can be found in ./out/<CONFIG>/log"
echo ""
echo ""
echo ""
BUILD_FAILED=0
for BUILD_PID in "${BUILD_PIDS[@]}"; do
	if ! wait "${BUILD_PID}"; then
		BUILD_FAILED=1
	fi
done

exit "${BUILD_FAILED}"
