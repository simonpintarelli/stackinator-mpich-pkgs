# stackinator-mpich-pkgs
Fetch cray-mpich, cray-gtl, cray-pmi, cray-pals from nexus and create binary tarballs. Patch `mpicc`, `mpicxx`, `mpifort` for stackinator cray-mpich spack package.

```bash
Usage: ./cray-mpich-tarballs.sh [-p proxy] repo
```

Example:
```bash
./cray-mpich-tarballs.sh https://nexus.cmn.alps.cscs.ch/service/rest/repository/browse/cpe-23.05-sles15-sp4/
```

Output:
```
a73a19d697cb083394f889ca7af82ad37d3cd80f64ca846c68cf19392c2e010d  archives/cray-gtl-8.1.26.tar.gz
ddc47a65acdc3cb1b95b23af2436d997d083ebf785582053f3c7ba6accce1090  archives/cray-mpich-8.1.26.tar.gz
cfc08dc80844c4b729fd0f3bc1d0230b0a7c7b9e88845dcf864f9d8ecea206a4  archives/cray-pals-1.2.12.tar.gz
9fd5b7b958c79f0dd29e68a2ad18315e26c0af059faaf350fac0ec71164d0122  archives/cray-pmi-6.1.11.tar.gz
```
