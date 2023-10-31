#!/usr/bin/bash

rpmdir=rpm
version_table=version.table
separate_packages=1

usage=$(
	cat <<-END
		Usage: $0 [-s <srcdir> -t <package list file>]
		    -s <srcdir>
		      the directory containing the rpms

		    -u only build a single package for mpich

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
while getopts "s: t: u h" opt; do
	case "$opt" in
	s)
		rpmdir="$OPTARG"
		;;
	t)
		version_table="$OPTARG"
		;;
	u)
		separate_packages=0
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

rpm2tar_pals() {
	## ----
	## PALS
	## ----
	echo "Processing cray-pals"
	_dst=$1
	mkdir -p ${_dst}
	find ${rpmdir} -name "*pals*.rpm" \
		-exec sh -c "rpm2cpio {} | bsdtar -C ${_dst}  -xf - --strip-components=6" \;
	version=$(grep pals ${version_table} | head -n1 | cut -f2 -d ' ')
	#tree unpack/pals >>log
	if [[ $separate_packages -eq 1 ]]; then
		tar czf "archives/cray-pals-${version}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* ${_dst}
	fi
}

rpm2tar_pmi() {
	## ---
	## PMI
	## ---
	echo "Processing cray-pmi"
	_dst=$1
	mkdir -p ${_dst}
	find ${rpmdir} -name "*pmi*.rpm" \
		-exec sh -c "rpm2cpio {} | bsdtar -C ${_dst}  -xf - --strip-components=6" \;
	version=$(grep cray-pmi ${version_table} | head -n1 | cut -f2 -d ' ')
	#tree unpack/pmi >>log
	if [[ $separate_packages -eq 1 ]]; then
		tar czf "archives/cray-pmi-${version}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* ${_dst}
	fi
}


rpm2tar_gtl() {
	## ---
	## GTL
	## ---
	echo "Processing cray-gtl"
	_dst=$1
	mkdir -p ${_dst}
	find ${rpmdir} -name "cray-mpich*gtl*" \
		-exec sh -c "rpm2cpio {} | bsdtar -C ${_dst} --include='opt/cray/pe/mpich/*' -xf - --strip-components=7" \;
	#tree -d unpack/gtl >>log
	version=$(grep gtl ${version_table} | head -n1 | cut -f2 -d ' ')
	if [[ $separate_packages -eq 1 ]]; then
		tar czf "archives/cray-gtl-${version}.tar.gz" "${tar_args[@]}" --exclude=*.a ${_dst}
	fi
}

repack_mpich-gcc() {
	## ---------
	## MPICH-GCC
	## ---------
	echo "Processing cray-mpich"
	## MPICH-GCC
	_dst=$1
	mkdir -p ${_dst}
	find ${rpmdir} -name "*mpich*gnu*" \
		-exec sh -c "rpm2cpio {} | bsdtar -C ${_dst} --include='opt/cray/pe/mpich/*/ofi/gnu/*' -xf - --strip-components=9 " \;
	#tree -d unpack/mpich/mpich-gcc >>log
	(
		cd ${_dst}/bin || exit 1
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

}

repack_mpich-nvhpc() {
	## -----------
	## MPICH-NVHPC
	## -----------
	_dst=$1
	mkdir -p ${_dst}
	find ${rpmdir} -name "*mpich*nvidia*" \
		-exec sh -c "rpm2cpio {} | bsdtar -C ${_dst} --include='opt/cray/pe/mpich/*/ofi/nvidia/*' -xf - --strip-components=9 " \;
	#tree -d unpack/mpich/mpich-nvhpc >>log
	(
		cd ${_dst}/bin || exit 1
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
}

if [[ $separate_packages -eq 1 ]]; then
	rpm2tar_pals unpack/pals
	rpm2tar_pmi unpack/pmi
	rpm2tar_gtl unpack/gtl

	repack_mpich-gcc unpack/mpich/mpich-gcc
	repack_mpich-nvhpc unpack/mpich/mpich-nvhpc
else
  _dst=unpack/mpich/mpich-gcc
	rpm2tar_pals ${_dst}
	rpm2tar_pmi ${_dst}
	rpm2tar_gtl ${_dst}
	repack_mpich-gcc ${_dst}

  _dst=unpack/mpich/mpich-nvhpc
	rpm2tar_pals ${_dst}
	rpm2tar_pmi ${_dst}
	rpm2tar_gtl ${_dst}
	repack_mpich-nvhpc ${_dst}
fi

## tar mpich-gcc and mpich-nvhpc
version=$(grep mpich ${version_table} | grep gnu | cut -f2 -d ' ')
tar czf "archives/cray-mpich-${version}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* --exclude=lib-abi-mpich unpack/mpich
