#!/usr/bin/bash

rpmdir=rpm
version_table=version.table
separate_packages=1
combine_gcc_nvhpc=0

usage=$(
	cat <<-END
		Usage: $0 [-s <srcdir> -t <package list file> [-i] [-x]]

		    -s <srcdir>
		      the directory containing the rpms

		    -i include all dependencies (gtl, pmi, pals) in mpich tarball

		    -x combine nvhpc|gcc in single cray-mpich tarball

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
while getopts "s: t: i x h" opt; do
	case "$opt" in
	s)
		rpmdir="$OPTARG"
		;;
	t)
		version_table="$OPTARG"
		;;
	i)
		separate_packages=0
		;;
	x)
		combine_gcc_nvhpc=1
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

# convert to absolute paths
rpmdir=$(realpath "$rpmdir")
version_table=$(realpath "$version_table")

mkdir -p archives
dstdir=$(realpath ./archives)

# make sure sha256 don't change
tar_args=(--sort=name --owner=0 --group=0 --numeric-owner --mode=go="rX,u+rw,a-s" --mtime="1970-01-01 01:01:01")

get_arch() {
    find ${rpmdir} -name "*pmi*.rpm" -print | tail -n1  | xargs rpm -qi | grep 'Architecture' | awk '//{print $2}'
}

rpm2tar_pals() {
	## ----
	## PALS
	## ----
	echo "Processing cray-pals"
	_dst=$1
	mkdir -p ${_dst}

  # extract rpm to tmpdir
  tmpdir=$(mktemp -d)
	find ${rpmdir} -name "*pals*.rpm" \
		   -exec sh -c "rpm2cpio {} | cpio -idmv -D ${tmpdir}" \;
  # find include, bin, lib directory in tmpdir
  find ${tmpdir} -name include -type d -exec cp -a {} ${_dst} \;
  find ${tmpdir} -name bin -type d -exec cp -a {} ${_dst} \;
  find ${tmpdir} -name lib -type d -exec cp -a {} ${_dst} \;

  rm -r ${tmpdir}

	#tree unpack/pals >>log
	if [[ $separate_packages -eq 1 ]]; then
      arch=$(get_arch)
	    version=$(grep pals ${version_table} | head -n1 | cut -f2 -d ' ')
		  tar czf "${dstdir}/cray-pals-${version}.${arch}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* ${_dst}
	fi
}

rpm2tar_pmi() {
	## ---
	## PMI
	## ---
	echo "Processing cray-pmi"
	_dst=$1
	mkdir -p ${_dst}
  tmpdir=$(mktemp -d)
	find ${rpmdir} -name "*pmi*.rpm" \
		-exec sh -c "rpm2cpio {} | cpio -idmv -D ${tmpdir}" \;
  # find include, bin, lib directory in tmpdir
  find ${tmpdir} -name include -type d -exec cp -a {} ${_dst} \;
  find ${tmpdir} -name bin -type d -exec cp -a {} ${_dst} \;
  find ${tmpdir} -name lib -type d -exec cp -a {} ${_dst} \;

  rm -r ${tmpdir}

	#tree unpack/pmi >>log
	if [[ $separate_packages -eq 1 ]]; then
      arch=$(get_arch)
	    version=$(grep cray-pmi ${version_table} | head -n1 | cut -f2 -d ' ')
		  tar czf "${dstdir}/cray-pmi-${version}.${arch}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* ${_dst}
	fi
}

rpm2tar_gtl() {
	## ---
	## GTL
	## ---
	echo "Processing cray-gtl"
	_dst=$1
	mkdir -p ${_dst}
  tmpdir=$(mktemp -d)
	find ${rpmdir} -name "cray-mpich*gtl*" \
		   -exec sh -c "rpm2cpio {} | cpio -idmv -D ${tmpdir}" \;
  # find include, bin, lib directory in tmpdir
  find ${tmpdir} -name include -type d -exec cp -a {} ${_dst} \;
  find ${tmpdir} -name bin -type d -exec cp -a {} ${_dst} \;
  find ${tmpdir} -name lib -type d -exec cp -a {} ${_dst} \;

  rm -r ${tmpdir}
	if [[ $separate_packages -eq 1 ]]; then
      arch=$(get_arch)
	    version=$(grep gtl ${version_table} | head -n1 | cut -f2 -d ' ')
		  tar czf "${dstdir}/cray-gtl-${version}.${arch}.tar.gz" "${tar_args[@]}" --exclude=*.a ${_dst}
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
  tmpdir=$(mktemp -d)
	find ${rpmdir} -name "*mpich*gnu*" \
		-exec sh -c "rpm2cpio {} | cpio -idmv -D ${tmpdir}" \;
  # find include, bin, lib directory in tmpdir
  find ${tmpdir} -name include -type d -exec cp -a {} ${_dst} \;
  find ${tmpdir} -name bin -type d -exec cp -a {} ${_dst} \;
  find ${tmpdir} -name lib -type d -exec cp -a {} ${_dst} \;

  rm -r ${tmpdir}

	(
		cd ${_dst}/bin || exit 1
		for i in mpicc mpicxx mpifort; do
			sed -i -e 's#^prefix=.*#prefix="@@PREFIX@@"#' \
				-e 's#^exec_prefix=.*#exec_prefix=$prefix#' \
				-e 's#^sysconfdir=.*#sysconfdir=$prefix/etc#' \
				-e 's#^includedir=.*#includedir=$prefix/include#' \
				-e 's#^modincdir=.*#modincdir=$prefix/include#' \
				-e 's#^libdir=.*#libdir=$prefix/lib#' $i
			sed -i '/^[[:space:]]*\$Show /s/-lmpi_gnu_\([0-9]\+\) /-Wl,--disable-new-dtags -Wl,-rpath,\$libdir -lmpi_gnu_\1 @@GTL_LIBRARY@@ /' $i
		done
		sed -i 's/^CXX=.*/CXX="@@CXX@@"/' mpicxx
		sed -i 's/^CC=.*/CC="@@CC@@"/' mpicc
		sed -i 's/^FC=.*/FC="@@FC@@"/' mpifort
	)

}

repack_mpich-nvhpc() {
	## -----------
	## MPICH-NVHPC
	## -----------
	_dst=$1
	mkdir -p ${_dst}
  tmpdir=$(mktemp -d)
	find ${rpmdir} -name "*mpich*nvidia*" \
		-exec sh -c "rpm2cpio {} | cpio -idmv -D ${tmpdir}" \;
  # find include, bin, lib directory in tmpdir
  find ${tmpdir} -name include -type d -exec cp -a {} ${_dst} \;
  find ${tmpdir} -name bin -type d -exec cp -a {} ${_dst} \;
  find ${tmpdir} -name lib -type d -exec cp -a {} ${_dst} \;

  rm -r ${tmpdir}

	(
		cd ${_dst}/bin || exit 1
		for i in mpicc mpicxx mpifort; do
			sed -i -e 's#^prefix=.*#prefix="@@PREFIX@@"#' \
				-e 's#^exec_prefix=.*#exec_prefix=$prefix#' \
				-e 's#^sysconfdir=.*#sysconfdir=$prefix/etc#' \
				-e 's#^includedir=.*#includedir=$prefix/include#' \
				-e 's#^modincdir=.*#modincdir=$prefix/include#' \
				-e 's#^libdir=.*#libdir=$prefix/lib#' $i
			sed -i '/^[[:space:]]*\$Show /s/-lmpi_nvidia /-Wl,--disable-new-dtags -Wl,-rpath,\$libdir -lmpi_nvidia @@GTL_LIBRARY@@ /' $i
		done
		sed -i 's/^CXX=.*/CXX="@@CXX@@"/' mpicxx
		sed -i 's/^CC=.*/CC="@@CC@@"/' mpicc
		sed -i 's/^FC=.*/FC="@@FC@@"/' mpifort
	)
}

if [[ $separate_packages -eq 1 ]]; then
	# create separate tarballs for pals, pmi, gtl and cray-mpich
	mkdir -p unpack
	(
		cd unpack || exit 1
		rpm2tar_pals pals
		rpm2tar_pmi pmi
		rpm2tar_gtl gtl
		repack_mpich-gcc mpich-gcc
		repack_mpich-nvhpc mpich-nvhpc

	)
else
	# include all dependencies in cray-mpich tarball
	mkdir -p unpack
	(
		cd unpack || exit 1
		_dst=mpich-gcc
		rpm2tar_pals ${_dst}
		rpm2tar_pmi ${_dst}
		rpm2tar_gtl ${_dst}
		repack_mpich-gcc ${_dst}

		_dst=mpich-nvhpc
		rpm2tar_pals ${_dst}
		rpm2tar_pmi ${_dst}
		rpm2tar_gtl ${_dst}
		repack_mpich-nvhpc ${_dst}
	)
fi

arch=$(get_arch)

## tar mpich-gcc and mpich-nvhpc
version=$(grep mpich ${version_table} | grep gnu | cut -f2 -d ' ')
if [[ $combine_gcc_nvhpc -eq 1 ]]; then
	(
		cd unpack || exit 1
		tar czf "${dstdir}/cray-mpich-${version}.${arch}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* --exclude=lib-abi-mpich mpich-gcc mpich-nvhpc
	)
else
	(
		cd unpack/ || exit 1
    tar czf "${dstdir}/cray-mpich-${version}-gcc.${arch}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* --exclude=lib-abi-mpich/ mpich-gcc
		tar czf "${dstdir}/cray-mpich-${version}-nvhpc.${arch}.tar.gz" "${tar_args[@]}" --exclude=*.a --exclude=*/pkgconfig/* --exclude=lib-abi-mpich mpich-nvhpc
	)
fi

set +x
echo
echo "Success! SHA256 sums:"
sha256sum ${dstdir}/*.tar.gz
