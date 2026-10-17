#!/usr/bin/env python3
"""
Select cray-mpich (gnu, nvidia, gtl, doc), cray-pmi and cray-pals rpms from a yum/dnf repo's
primary.xml (read from stdin, gzip or plain).

For each (name, arch) only the highest version-release is kept. By default only
the newest cray-mpich version is kept, override with --mpich-version.

Input (stdin): repodata/<sha>-primary.xml.gz of the repo, as fetched by curl.
It lists every package in the repo, roughly:

    <metadata xmlns="http://linux.duke.edu/metadata/common" ...>
      <package type="rpm">
        <name>cray-mpich-9.2.1-gnu123</name>
        <arch>aarch64</arch>
        <version epoch="0" ver="9.2.1" rel="1234.sles15sp6"/>
        <location href="aarch64/cray-mpich-9.2.1-gnu123-9.2.1-1234.sles15sp6.aarch64.rpm"/>
        ...
      </package>
      ...
    </metadata>

Output (stdout, one line per rpm), compatible with rpm2tar.sh's version table:
    <location> <version>
where <location> is the path relative to the repo base url.
"""

import argparse
import gzip
import re
import sys
import xml.etree.ElementTree as ET
from typing import NamedTuple

# primary.xml puts all elements in this namespace, find() needs the prefix
NS = {"c": "http://linux.duke.edu/metadata/common"}

# matched against <name> (full match)
DEFAULT_PATTERNS = [
    r"cray-mpich-[\d.]+-(gnu|nvidia)\d+(-devel|-fortran)?",
    r"cray-mpich-[\d.]+-(gtl|doc)",
    r"cray-pmi(-devel|-doc)?(-[\d.]+)?",
    r"cray-pals(-[\d.]+)?",
]


def vkey(s):
    """Rough rpmvercmp: compare numeric and alpha chunks.

    "9.2.10" -> [(0, 9), (0, 2), (0, 10)], so that 9.2.10 > 9.2.9.
    The 0/1 tag keeps ints and strs from being compared with each other.
    """
    return [(0, int(t)) if t.isdigit() else (1, t) for t in re.findall(r"\d+|[a-zA-Z]+", s)]


class Pkg(NamedTuple):
    name: str
    arch: str
    ver: str
    rel: str
    loc: str  # path relative to the repo base url


def newer(a, b):
    """True if Pkg a has a higher version-release than Pkg b."""
    return (vkey(a.ver), vkey(a.rel)) > (vkey(b.ver), vkey(b.rel))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--arch", default="aarch64", help="aarch64|x86_64 (noarch is always included)")
    ap.add_argument("--mpich-version", help="e.g. 9.2.0 (default: newest)")
    ap.add_argument("--pattern", action="append", help="name regex (full match), repeatable; replaces defaults")
    ap.add_argument("--all-builds", action="store_true", help="keep all builds, not just the newest per name")
    args = ap.parse_args()

    # 1. parse primary.xml
    #    in:  raw bytes of primary.xml(.gz) from stdin (gzip detected by its magic number)
    #    out: root, the <metadata> element
    primary_xml = sys.stdin.buffer.read()
    if primary_xml[:2] == b"\x1f\x8b":
        primary_xml = gzip.decompress(primary_xml)
    root = ET.fromstring(primary_xml)

    # 2. filter packages by arch and name
    #    in:  all <package> elements
    #    out: pkgs, list of Pkg, e.g.
    #         Pkg(name="cray-mpich-9.2.1-gnu123", arch="aarch64", ver="9.2.1", rel="1234.sles15sp6",
    #             loc="aarch64/cray-mpich-9.2.1-gnu123-9.2.1-1234.sles15sp6.aarch64.rpm")
    pats = [re.compile(p) for p in (args.pattern or DEFAULT_PATTERNS)]
    pkgs = []
    for p in root.findall("c:package", NS):
        name = p.findtext("c:name", namespaces=NS)
        arch = p.findtext("c:arch", namespaces=NS)
        if arch not in (args.arch, "noarch"):
            continue
        if not any(r.fullmatch(name) for r in pats):
            continue
        v = p.find("c:version", NS)
        loc = p.find("c:location", NS).get("href")
        pkgs.append(Pkg(name, arch, v.get("ver"), v.get("rel"), loc))

    # 3. restrict cray-mpich to a single version
    #    in:  pkgs, possibly with several mpich versions (9.2.0 and 9.2.1)
    #    out: pkgs, cray-mpich-* only of --mpich-version (or the newest), others untouched
    mpich_vers = {p.ver for p in pkgs if p.name.startswith("cray-mpich-")}
    if mpich_vers:
        want = args.mpich_version or max(mpich_vers, key=vkey)
        if want not in mpich_vers:
            sys.exit(f"mpich version {want} not found, available: {sorted(mpich_vers, key=vkey)}")
        pkgs = [p for p in pkgs if not p.name.startswith("cray-mpich-") or p.ver == want]

    # 4. keep the newest build per package
    #    in:  pkgs, possibly with several builds of the same (name, arch),
    #         e.g. cray-mpich-9.2.0-gnu123 rel 1139 and 1186
    #    out: pkgs, one entry per (name, arch) with the highest (ver, rel)
    if not args.all_builds:
        best = {}
        for p in pkgs:
            k = (p.name, p.arch)
            if k not in best or newer(p, best[k]):
                best[k] = p
        pkgs = list(best.values())

    # 5. print
    #    in:  pkgs
    #    out: "<location> <version>" lines on stdout, sorted by name
    for p in sorted(pkgs):
        # cray-pmi encodes the version in the name and has ver=0
        m = re.search(r"\d+\.\d+(\.\d+)*", p.name)
        print(p.loc, m.group(0) if m else p.ver)


if __name__ == "__main__":
    main()
