# stackinator-mpich-pkgs
Fetch cray-mpich, cray-gtl, cray-pmi, cray-pals from nexus repository and create binary tarballs. Patch `mpicc`, `mpicxx`, `mpifort` for stackinator cray-mpich spack package.

```bash
Usage: ./cray-mpich-tarballs.sh [-p proxy] [-o destdir] repo
```

Example:
```bash
./cray-mpich-tarballs.sh https://nexus.cmn.alps.cscs.ch/service/rest/repository/browse/cpe-23.05-sles15-sp4/
```

## Hashes
```
5ac6b0877fd0f6afaaf391fffef41daf4d3150edc3250721c9abd4ded6b58486  22.08-sp3/archives/cray-gtl-8.1.18.tar.gz
45d519be217cea89c58893d25826b15d99183247d15ecee9c3f64913660d79c2  22.08-sp3/archives/cray-mpich-8.1.18.tar.gz
eaefdd5d7e8031a617ecb1277d4fc79cc34b150a1d109358db0118f66de45a14  22.08-sp3/archives/cray-pals-1.2.0.tar.gz
4fc1f8cc32a98f7f3d339915564347b75db8c373647f748bde01daaf0ac4bf70  22.08-sp3/archives/cray-pmi-6.0.17.tar.gz

44ba43d31721031d54bdce5b722ed0cd7f3bc39dae08141b93b2e779b7900e4e  22.11-sp3/archives/cray-gtl-8.1.21.tar.gz
ea8921a2f08b0a85e35c2123235f09d2f86d9b092f32f72c5e025e8c5264732e  22.11-sp3/archives/cray-mpich-8.1.21.tar.gz
ec5b61a9dcabb6acf2edba305570f0ed9beed80ccec2d3a3f0afd853f080645b  22.11-sp3/archives/cray-pals-1.2.4.tar.gz
7cf52023ef54d82e1836712b12bf6f6a179ae562e35b0f710ca4c7086f4e35e5  22.11-sp3/archives/cray-pmi-6.1.7.tar.gz

9ea85f8bcc623fd5c8d6b46dec776a90c8c8d9a85abb43d3836eb89697e6e5b8  22.12-sp4/archives/cray-gtl-8.1.23.tar.gz
e56a5cd2aea3418638c121efc5e4a0ae3b369a2a45b9afc07c5e2086a59f35d7  22.12-sp4/archives/cray-mpich-8.1.23.tar.gz
81bfbd433f3276694da3565c1be03dd47887e344626bfe7f43d0de1d73fcb567  22.12-sp4/archives/cray-pals-1.2.5.tar.gz
b8e94335ca3857dc4895e416b91eaeaee5bfbbe928b5dcfc15300239401a8b7b  22.12-sp4/archives/cray-pmi-6.1.8.tar.gz

980cbc3538501e5422528e12cb7b99d3e5b21e029e17f55decbbf4812c793aaa  23.02-sp3/archives/cray-gtl-8.1.24.tar.gz
2d77b39a5399143d3b31de025515d0bd557dd9ea9ba152b9ef5ff6f6b39eed4b  23.02-sp3/archives/cray-mpich-8.1.24.tar.gz
e563a6a8962c15deebc466454fe6860576e33c52fd2cbdcd125e2164613c29fa  23.02-sp3/archives/cray-pals-1.2.9.tar.gz
9839585ca211b665b66a34ee9d81629a7529bebef45b664d55e9b602255ca97e  23.02-sp3/archives/cray-pmi-6.1.9.tar.gz


527c63823ea3a15ca989ded43f8b085e40baad38b9276d6893b8dce3fdf91254  23.03-sp3/archives/cray-gtl-8.1.25.tar.gz
98dcd4ff715a8e8f1af9e9c4732a671d7d5241ce3bc6ecfa463e570b19f969ff  23.03-sp3/archives/cray-mpich-8.1.25.tar.gz
52c11e864a603fa07a37ce508fa8b9861b30d15e83c16e33612df5ee85ca6135  23.03-sp3/archives/cray-pals-1.2.11.tar.gz
548dc1ed44b86ca85f52da1bb6af9abbfb71a6a434170f86bbf9219cb2f0a913  23.03-sp3/archives/cray-pmi-6.1.10.tar.gz

319e4e2ac0f06c1272ac6ba756924e2a5b239857b3a3b58e7a9a4672aa63c138  23.05-sp4/archives/cray-gtl-8.1.26.tar.gz
0f26f7cc691d6378f9eddc66d896f363bfd2f2a1e40d916aa469d5cc0ae6f486  23.05-sp4/archives/cray-mpich-8.1.26.tar.gz
0bcade87c7e466f5ba6c5d096a084764ebae5b5b2ecdb90f3f01b00cd9545337  23.05-sp4/archives/cray-pals-1.2.12.tar.gz
de6c6b3e31ff884c0192c7bac7b999167710850cae8a663f5c20c4af30f40c3d  23.05-sp4/archives/cray-pmi-6.1.11.tar.gz
```


## Notes
- In `cray-mpich-8.1.18-nvidia207-0-4.sles15sp3.x86_64.rpm` `bin/mpicc`, `bin/mpicxx`, `bin/mpifort` are missing


## Build directly from rpms on disk

Prerequisites:
- rpms for `gtl`, `pals`, `pmi` and `mpich` are available locally.
- a file `version.table` with  entries
```
<filename1>.rpm <version1>
...
<filenameN>.rpm <versionN>
```

### Examples

Create `cray-mpich-<mpich-ver>-gcc.tar.gz` and `cray-mpich-<mpich-ver>-nvhpc.tar.gz` with `pmi`, `gtl`, `pals` included (`-i`).
```bash
./rpm2tar.sh -s /path/to/rpms_dir -t version.table -i
```

Create `cray-mpich-<mpich-ver>.tar.gz` containing both `nvhpc` and `gcc` in subdirectories.  With `pmi`, `gtl`, `pals` included.
```bash
./rpm2tar.sh -s /path/to/rpms_dir -t version.table -i -x
```

Create `cray-mpich-<mpich-ver>.tar.gz` containing both `nvhpc` and `gcc` in subdirectories (`-x`). `pmi`, `gtl`, `pals` in separate tarballs.
```bash
./rpm2tar.sh -s /path/to/rpms_dir -t version.table -x
```

