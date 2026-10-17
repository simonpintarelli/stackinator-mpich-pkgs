#!/usr/bin/bash
#
# Usage: repo-fetch.sh <repo-base-url> <outdir> [repo-select.py args...]
#
#   repo-fetch.sh https://update1.linux.hpe.com/repo/cpe/26.09/experimental/sle/15.7 GH-26.09 --arch aarch64
#
# Writes <outdir>/version.table and downloads the rpms to <outdir>/rpm.
# Set DRYRUN=1 to only write version.table.
# Credentials are read from $NETRC (default ~/.netrc-hpe).

set -euo pipefail

base=${1:?repo url}
out=${2:?outdir}
shift 2

c=(curl -sSf --netrc-file "${NETRC:-$HOME/.netrc-hpe}")
here=$(dirname "$(realpath "$0")")

# 1. find primary.xml
#    in:  $base/repodata/repomd.xml, the repo index listing the metadata files
#    out: $primary, its path relative to $base, e.g.
#         repodata/f765...0480-primary.xml.gz (the name contains a checksum, so it changes)
primary=$("${c[@]}" "$base/repodata/repomd.xml" | grep -o 'href="repodata/[^"]*primary.xml[^"]*"' | cut -d'"' -f2)

# 2. select rpms
#    in:  $base/$primary, the list of all packages (name, arch, version, location)
#    out: $list, "<location> <version>" per rpm, e.g.
#         aarch64/cray-mpich-9.2.1-gnu123-9.2.1-1234.sles15sp6.aarch64.rpm 9.2.1
mkdir -p "$out/rpm"
list=$("${c[@]}" "$base/$primary" | python3 -I "$here/repo-select.py" "$@")
echo "$list"

# 3. write version table
#    in:  $list
#    out: $out/version.table, "<file>.rpm <version>" per rpm (rpm2tar.sh expects bare file names)
awk '{ n = split($1, a, "/"); print a[n], $2 }' <<<"$list" >"$out/version.table"

[[ -n ${DRYRUN:-} ]] && exit 0

# 4. download
#    in:  $list, locations relative to $base
#    out: $out/rpm/<file>.rpm, files already present are skipped
while read -r loc _; do
	f=$out/rpm/${loc##*/}
	[[ -e $f ]] && continue
	"${c[@]}" -o "$f" "$base/$loc"
done <<<"$list"
