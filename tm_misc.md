## Miscellaneous topics

Here is some additional information for deeper learning.

* Compilation of P4 programs

___

### Compilation of P4 programs

If you want to create your own P4 switch program, compilation of the P4 program is necessary.

The explanation here assumes a situation where the P4 program `test.p4` to be compiled exists under the `/tmp/P4Runtime-protoswitch/test` directory.

```bash
$ ls /tmp/P4runtime-protoswitch/test
test.p4
$  
```

#### Starting the P4C container

Start the P4C Docker container as follows.

```bash
$ docker run -it -v /tmp/P4Runtime-protoswitch/:/tmp/ p4lang/p4c /bin/bash
root@ab1f99459b1a:/p4c# cd /tmp/test
root@ab1f99459b1a:/tmp/test# ls
test.p4
root@ab1f99459b1a:/tmp/test# 
```

##### Notes for ARM Mac version

If you got an error such as **"no matching manifest for linux/arm64/v8 in the manifest list entries"** in the above operation, are you using a Mac with an ARM processor?

```bash
$ docker run -it -v /tmp/P4Runtime-protoswitch/:/tmp/ p4lang/p4c /bin/bash
Unable to find image 'p4lang/p4c:latest' locally
latest: Pulling from p4lang/p4c
docker: no matching manifest for linux/arm64/v8 in the manifest list entries
$
```

To run P4C (and P4 Runtime Shell) on an ARM-based Mac, it is currently necessary to enable Rosetta. Check "Use Rosetta for x86_64/amd64 emulation on Apple Silicon" in Dockerhub Settings >> General >> Virtual Machine Options. After that, it is probably good to add the platform option to the docker command, such as ```$ docker run --platform=linux/amd64 ...```.

#### Compilation by P4C

Note that the host `/tmp/P4Runtime-protoswitch` directory and docker `/tmp` are synchronized.

Therefore, compile `test.p4`, which should be visible under `/tmp/test` as seen from the p4c container.

```bash
root@ab1f99459b1a:/p4c# cd /tmp/test
root@ab1f99459b1a:/tmp/test# ls
test.p4
root@ab1f99459b1a:/tmp/test# p4c --target bmv2 --arch v1model --p4runtime-files p4info.txtpb test.p4 
root@ab1f99459b1a:/tmp/test# ls
p4info.txtpb  test.json  test.p4  test.p4i
root@ab1f99459b1a:/tmp/test# 
```

P4Runtime Shell is then started using the generated `p4info.txtpb` and `test.json`.

Files such as `p4info.txtpb` and `proto01.json` prepared for each tutorial were created in this way.

##### If you get an error that libboost_iostreams.so.1.71.0 is missing

If you get an error like the following when compiling, your container image is most likely version 1.2.5.7 or later and earlier than 1.2.5.13.

```bash
root@897ac728fb57:/p4c# cd /tmp
root@897ac728fb57:/tmp# p4c --target bmv2 --arch v1model --p4runtime-files p4info.txtpb test.p4 
/usr/local/bin/p4c-bm2-ss: error while loading shared libraries: libboost_iostreams.so.1.71.0: cannot open shared object file: No such file or directory
root@897ac728fb57:/tmp#
```

Apparently, a little while ago (probably version 1.2.5.7 on Jun 4, 2025), too many libraries were removed from the package, and the `libboost` library was omitted. I submitted Issue [#5593](https://github.com/p4lang/p4c/issues/5593) to p4lang earlier (April 19, 2026), so it was expected to be fixed soon. In fact, a Pull Request for the fix [#5612](https://github.com/p4lang/p4c/pull/5612) was submitted and accepted on May 7, 2026, and the issue has been resolved in version 1.2.5.13.

However, it is also possible to deal with it by manually installing `libboost` into the running container as follows.

```bash
# apt update 
# apt install -y libboost-iostreams1.71.0
```
