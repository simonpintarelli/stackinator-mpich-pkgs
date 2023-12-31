#!/usr/bin/bash

set -eux -o pipefail

# Default value for proxy
proxy=""
dest="output"
separate_packages=1

usage="Usage: $0 [-p proxy] [-o workdir] [-i] repo"
# Parse command-line options
while getopts "p: o: i" opt; do
	  case "$opt" in
	      p)
		        proxy="--socks5-hostname $OPTARG"
		        ;;
        i)
		        separate_packages=0
		        ;;
	      o)
		        dest="$OPTARG"
		        ;;
	      *)
		        echo "${usage}"
		        exit 1
		        ;;
	  esac
done
shift $((OPTIND - 1))

# Check for remaining arguments
if [[ $# -lt 1 ]]; then
	  echo "${usage}"
	  exit 1
fi

repo="$1"
rpmdir=rpm

rm -f log

rm -rf "${dest}"
mkdir -p "${dest}"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
(
    cd ${dest}
	  # donwload index and rpms
	  # https://nexus.cmn.alps.cscs.ch/service/rest/repository/browse/cpe-23.05-sles15-sp4/
	  curl -ks $proxy $repo -o index.html
	  index=$(curl -ks $proxy $repo | python "${SCRIPT_DIR}"/parse-index.py)
    # debug putput
	  echo >version.table
	  rm -rf ${rpmdir} && mkdir -p ${rpmdir}
	  while IFS=' ' read -r name url version; do
		    echo "$name $version" >>version.table
		    curl -k $proxy -o ${rpmdir}/$name $url
	  done <<<"$index"

    if [[ $separate_packages -eq 1 ]]; then
        ${SCRIPT_DIR}/rpm2tar.sh -t version.table -s ${rpmdir}
    else
        ${SCRIPT_DIR}/rpm2tar.sh -t version.table -s ${rpmdir} -i
  fi
)

sha256sum "${dest}"/archives/*tar.gz
