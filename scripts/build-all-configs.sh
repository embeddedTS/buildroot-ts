#!/bin/bash -e

# XXX: Must be run from root dir of buildroot-ts tree!

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



echo "WARNING! This will start" $(ls technologic/configs/ts* | wc -l) "parallel builds!"
echo "Press ctrl+c to stop this within 10 seconds"
sleep 10

docker build --quiet --tag "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" docker/

unset DOCKER_PIDS
for CONFIG in technologic/configs/*; do
  CONFIG=$(basename ${CONFIG})
  BOARD=${CONFIG%_*}
  if [ "${BOARD}" == "extra_packages" ]; then continue; fi
  mkdir -p "out/${BOARD}"
  ARG="O=/work/out/${BOARD} ${CONFIG} all"
  DOCKER_PID=$(docker run -d --rm -it --volume $(pwd):/work -w /work -e HOME=/work --user $(id -u):$(id -g) "buildroot-buildenv-$(git rev-parse --short=12 HEAD)" bash -c "make ${ARG} >/work/out/"${BOARD}"/log")
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


