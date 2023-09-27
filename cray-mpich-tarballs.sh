#!/usr/bin/bash

set -eu -o pipefail

# Default value for proxy
proxy=""

# Parse command-line options
while getopts "p:" opt; do
    case "$opt" in
        p)
            proxy="--socks5-hostname $OPTARG"
            ;;
        *)
            echo "Usage: $0 [-p proxy] repo"
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Check for remaining arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 [-p proxy] repo"
    exit 1
fi

repo="$1"


rm -f log

# donwload index and rpms
# https://nexus.cmn.alps.cscs.ch/service/rest/repository/browse/cpe-23.05-sles15-sp4/
index=$(curl -ks $proxy $repo | python parse-index.py 2> /dev/null)
echo > version.table
rm -rf downloads && mkdir -p downloads
while IFS=' ' read -r name url version; do
    echo "$name $version" >> version.table
    curl -k $proxy -o downloads/$name $url
done <<< "$index"

## ----
## PALS
## ----
rm -rf unpack/pals && mkdir -p unpack/pals
find downloads -name "*pals*.rpm"  -exec sh -c "rpm2cpio {} | bsdtar -C unpack/pals  -xf - --strip-components=6" \;
version=$(grep pals version.table | cut -f2 -d ' ')
tree unpack/pals >> log
mkdir -p archives
tar czf "archives/cray-pals-${version}.tar.gz" --exclude=*.a --exclude=*/pkgconfig/* unpack/pals

## ---
## PMI
## ---
rm -rf unpack/pmi && mkdir -p unpack/pmi
find downloads -name "*pmi*.rpm"  -exec sh -c "rpm2cpio {} | bsdtar -C unpack/pmi  -xf - --strip-components=6" \;
version=$(grep cray-pmi-devel version.table | cut -f2 -d ' ')
tree unpack/pmi >> log
mkdir -p archives
tar czf "archives/cray-pmi-${version}.tar.gz" --exclude=*.a --exclude=*/pkgconfig/* unpack/pmi

## ---
## GTL
## ---
rm -rf unpack/gtl && mkdir -p unpack/gtl
find downloads -name cray-mpich*gtl* -exec sh -c "rpm2cpio {} | bsdtar -C unpack/gtl --include='opt/cray/pe/mpich/*' -xf - --strip-components=7" \;
tree -d unpack/gtl >> log
version=$(grep gtl version.table | cut -f2 -d ' ')
mkdir -p archives
tar czf "archives/cray-gtl-${version}.tar.gz" --exclude=*.a  unpack/gtl


rm -rf unpack/mpich
mkdir -p unpack/mpich
## MPICH-GCC
mkdir -p unpack/mpich/mpich-gcc
find downloads -name *mpich*gnu* -exec sh -c "rpm2cpio {} | bsdtar -C unpack/mpich/mpich-gcc --include='opt/cray/pe/mpich/*/ofi/gnu/*' -xf - --strip-components=9 " \;
tree -d unpack/mpich/mpich-gcc >> log
(
    cd unpack/mpich/mpich-gcc/bin || exit 1
    for i in mpicc mpicxx mpifort;
    do
     sed -i -e 's#^prefix=.*#prefix="@@PREFIX@@"#' \
         -e 's#^exec_prefix=.*#exec_prefix=$prefix#' \
         -e 's#^sysconfdir=.*#sysconfdir=$prefix/etc#' \
         -e 's#^includedir=.*#includedir=$prefix/include#' \
         -e 's#^libdir=.*#libdir=$prefix/lib#' $i
     sed -i '/^[[:space:]]*\$Show /s/-lmpi_gnu_91 /-lmpi_gnu_91 @@GTL_LIBRARY@@ /' $i
    done
    sed -i 's/^CXX.*/CXX="@@CXX@@"/' mpicxx
    sed -i 's/^CC.*/CC="@@CC@@"/' mpicc
    sed -i 's/^FC.*/FC="@@FC@@"/' mpicc
)
## MPICH-NVHPC
mkdir -p unpack/mpich/mpich-nvhpc
find downloads -name *mpich*nvidia* -exec sh -c "rpm2cpio {} | bsdtar -C unpack/mpich/mpich-nvhpc --include='opt/cray/pe/mpich/*/ofi/nvidia/*' -xf - --strip-components=9 " \;
tree -d unpack/mpich/mpich-nvhpc >> log
(
    cd unpack/mpich/mpich-nvhpc/bin || exit 1
    for i in mpicc mpicxx mpifort;
    do
        sed -i -e 's#^prefix=.*#prefix="@@PREFIX@@"#' \
            -e 's#^exec_prefix=.*#exec_prefix=$prefix#' \
            -e 's#^sysconfdir=.*#sysconfdir=$prefix/etc#' \
            -e 's#^includedir=.*#includedir=$prefix/include#' \
            -e 's#^libdir=.*#libdir=$prefix/lib#' $i
        sed -i '/^[[:space:]]*\$Show /s/-lmpi_nvidia /-lmpi_nvidia @@GTL_LIBRARY@@ /' $i
    done
    sed -i 's/^CXX.*/CXX="@@CXX@@"/' mpicxx
    sed -i 's/^CC.*/CC="@@CC@@"/' mpicc
    sed -i 's/^FC.*/FC="@@FC@@"/' mpicc
)
version=$(grep mpich version.table | grep gnu | cut -f2 -d ' ')
mkdir -p archives
tar czf "archives/cray-mpich-${version}.tar.gz" --exclude=*.a --exclude=*/pkgconfig/* --exclude=lib-abi-mpich  unpack/mpich

sha256sum archives/*tar.gz
