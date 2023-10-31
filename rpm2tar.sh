#!/usr/bin/bash

rpmdir=rpm
version_table=version.table

usage=$(
	cat <<-END
		Usage: $0 [-s <srcdir> -t <package list file>]
		    -s <srcdir>
		      the directory containing the rpms

		    -t <package list file>
		      must be in the format <fname.rpm> <version>, for example

		        cray-mpich-8.1.26-gnu91-0-24.sles15sp4.x86_64.rpm 8.1.26
		        cray-mpich-8.1.26-nvidia207-0-24.sles15sp4.x86_64.rpm 8.1.26

		      it must contain the following rpms:
		      - cray-mpich (for gnu)
		      - cray-mpich (for nvidia)
		      - cray-mpi
		      - cray-mpi-devel
		      - cray-pals
	END
)

# Parse command-line options
while getopts "s: t: h" opt; do
	case "$opt" in
	s)
		rpmdir="$OPTARG"
		;;
	t)
		version_table="$OPTARG"
		;;
	h)
		echo "${usage}"
		exit 0
		;;
	*)
		echo "${usage}"
		exit 1
		;;
	esac
done

set -eux -o pipefail
# make sure sha256 don't change
tar_args=(--sort=name --owner=0 --group=0 --numeric-owner --mode=go="rX,u+rw,a-s" --mtime="1970-01-01 01:01:01")

mkdir -p archives
## ----
## PALS
## ----
echo "Processing cray-pals"
mkdir -p unpack/pals
find ${rpmdir} -name "*pals*.rpm" \
	-exec sh -c 'rpm2cpio {} | bsdtar -C unpack/pals  -xf - --strip-components=6' \;
version=$(grep pals ${version_table} | head -n1 | cut -f2 -d ' ')
#tree unpack/pals >>log
tar czf "archives/cray-pals-${version}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* unpack/pals

## ---
## PMI
## ---
echo "Processing cray-pmi"
mkdir -p unpack/pmi
find ${rpmdir} -name "*pmi*.rpm" \
	-exec sh -c 'rpm2cpio {} | bsdtar -C unpack/pmi  -xf - --strip-components=6' \;
version=$(grep cray-pmi ${version_table} | head -n1 | cut -f2 -d ' ')
#tree unpack/pmi >>log
tar czf "archives/cray-pmi-${version}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* unpack/pmi

## ---
## GTL
## ---
echo "Processing cray-gtl"
mkdir -p unpack/gtl
find ${rpmdir} -name "cray-mpich*gtl*" \
	-exec sh -c "rpm2cpio {} | bsdtar -C unpack/gtl --include='opt/cray/pe/mpich/*' -xf - --strip-components=7" \;
#tree -d unpack/gtl >>log
version=$(grep gtl ${version_table} | head -n1 | cut -f2 -d ' ')
tar czf "archives/cray-gtl-${version}.tar.gz" "${tar_args[@]}" --exclude=*.a unpack/gtl


## ---
## GTL
## ---
echo "Processing cray-mpich"
mkdir -p unpack/mpich
## MPICH-GCC
mkdir -p unpack/mpich/mpich-gcc
find ${rpmdir} -name "*mpich*gnu*" \
	-exec sh -c "rpm2cpio {} | bsdtar -C unpack/mpich/mpich-gcc --include='opt/cray/pe/mpich/*/ofi/gnu/*' -xf - --strip-components=9 " \;
#tree -d unpack/mpich/mpich-gcc >>log
(
	cd unpack/mpich/mpich-gcc/bin || exit 1
	for i in mpicc mpicxx mpifort; do
		sed -i -e 's#^prefix=.*#prefix="@@PREFIX@@"#' \
			-e 's#^exec_prefix=.*#exec_prefix=$prefix#' \
			-e 's#^sysconfdir=.*#sysconfdir=$prefix/etc#' \
			-e 's#^includedir=.*#includedir=$prefix/include#' \
			-e 's#^modincdir=.*#modincdir=$prefix/include#' \
			-e 's#^libdir=.*#libdir=$prefix/lib#' $i
		sed -i '/^[[:space:]]*\$Show /s/-lmpi_gnu_91 /-lmpi_gnu_91 @@GTL_LIBRARY@@ /' $i
	done
	sed -i 's/^CXX.*/CXX="@@CXX@@"/' mpicxx
	sed -i 's/^CC.*/CC="@@CC@@"/' mpicc
	sed -i 's/^FC.*/FC="@@FC@@"/' mpicc
)
## MPICH-NVHPC
mkdir -p unpack/mpich/mpich-nvhpc
find ${rpmdir} -name "*mpich*nvidia*" \
	-exec sh -c "rpm2cpio {} | bsdtar -C unpack/mpich/mpich-nvhpc --include='opt/cray/pe/mpich/*/ofi/nvidia/*' -xf - --strip-components=9 " \;
#tree -d unpack/mpich/mpich-nvhpc >>log
(
	cd unpack/mpich/mpich-nvhpc/bin || exit 1
	for i in mpicc mpicxx mpifort; do
		sed -i -e 's#^prefix=.*#prefix="@@PREFIX@@"#' \
			-e 's#^exec_prefix=.*#exec_prefix=$prefix#' \
			-e 's#^sysconfdir=.*#sysconfdir=$prefix/etc#' \
			-e 's#^includedir=.*#includedir=$prefix/include#' \
			-e 's#^modincdir=.*#modincdir=$prefix/include#' \
			-e 's#^libdir=.*#libdir=$prefix/lib#' $i
		sed -i '/^[[:space:]]*\$Show /s/-lmpi_nvidia /-lmpi_nvidia @@GTL_LIBRARY@@ /' $i
	done
	sed -i 's/^CXX.*/CXX="@@CXX@@"/' mpicxx
	sed -i 's/^CC.*/CC="@@CC@@"/' mpicc
	sed -i 's/^FC.*/FC="@@FC@@"/' mpicc
)
version=$(grep mpich ${version_table} | grep gnu | cut -f2 -d ' ')
tar czf "archives/cray-mpich-${version}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* --exclude=lib-abi-mpich unpack/mpich
