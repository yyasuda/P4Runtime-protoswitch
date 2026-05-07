## Tutorial 0: Preparing the experimental environment

In this tutorial, experiments are performed by starting Mininet and connecting P4 Runtime Shell, which acts as the controller, to it.

### System structure

The system structure of the environment used in this experiment is shown in the figure below. The switch is prepared as a 3-port switch using a Mininet environment. P4Runtime Shell is used in the role of the controller.

<img src="./t0_structure.png" alt="attach:(system structure)" title="System Structure" width="500">

In P4Runtime, the controller and the switch are connected using gRPC. When starting Mininet, the port number (TCP 5000) for connection using gRPC is specified. When starting P4Runtime Shell, the IP address and port number of the Mininet environment to be connected are specified. When P4Runtime Shell is started, it similarly installs the P4 program specified at startup into the switch through the gRPC connection.

The concrete procedure is shown below.

### Starting Mininet

Here, [P4Runtime-enabled Mininet Docker Image](https://hub.docker.com/repository/docker/yutakayasuda/p4mn) is used as the switch. It is probably good to start it as follows.

Start a P4Runtime-enabled Mininet environment in a Docker environment. Note that the `--arp` and `--mac` options are specified at startup so that ping tests and similar operations can be performed without ARP processing.

```bash
$ docker run --privileged --rm -it -p 50001:50001 -e LOGLEVEL=debug -e PKTDUMP=true -e IPV6=false yutakayasuda/p4mn --arp --topo single,3 --mac
*** Error setting resource limits. Mininet's performance may be affected.
*** Creating network
*** Adding controller
*** Adding hosts:
h1 h2 h3 
*** Adding switches:
s1 
*** Adding links:
(h1, s1) (h2, s1) (h3, s1) 
*** Configuring hosts
h1 h2 h3 
*** Starting controller

*** Starting 1 switches
s1 ...⚡️ simple_switch_grpc @ 50001

*** Starting CLI:
mininet> 
```

You can confirm that port 1 of s1 is connected to h1, port 2 to h2, and port 3 to h3.

```bash
mininet> net
h1 h1-eth0:s1-eth1
h2 h2-eth0:s1-eth2
h3 h3-eth0:s1-eth3
s1 lo:  s1-eth1:h1-eth0 s1-eth2:h2-eth0 s1-eth3:h3-eth0
mininet> 
```

The MAC address of the interface h1-eth0, which connects h1 to the switch, is 00:00:00:00:00:01. Similarly, h2 has 00:00:00:00:00:02, and h3 has 00:00:00:00:00:03.

##### Log data

From the options `-e LOGLEVEL=debug -e PKTDUMP=true` specified at Mininet startup, you can see that log files are created under the `/tmp` directory in the Mininet container. Mininet has a command called sh, and this passes the following description to the sh command shell for execution.

```bash
mininet> sh ls -l /tmp
total 16
-rw-r--r-- 1 root root    5 Apr 24 10:59 bmv2-s1-grpc-port
-rw-r--r-- 1 root root 1073 Apr 24 10:59 bmv2-s1-log
-rw-r--r-- 1 root root 1095 Apr 24 10:59 bmv2-s1-netcfg.json
-rw-r--r-- 1 root root   32 Apr 24 10:59 bmv2-s1-watchdog.out
-rw-r--r-- 1 root root    0 Apr 24 10:59 s1-eth1_in.pcap
-rw-r--r-- 1 root root    0 Apr 24 10:59 s1-eth1_out.pcap
-rw-r--r-- 1 root root    0 Apr 24 10:59 s1-eth2_in.pcap
-rw-r--r-- 1 root root    0 Apr 24 10:59 s1-eth2_out.pcap
-rw-r--r-- 1 root root    0 Apr 24 10:59 s1-eth3_in.pcap
-rw-r--r-- 1 root root    0 Apr 24 10:59 s1-eth3_out.pcap
mininet> 
```

s1-eth1_in.pcap is the log of packets that entered port 1 of switch s1. Since h1-eth0 is connected to s1-eth1, this also means that it is the log of packets sent from host h1.

Similarly, s1-eth1_out.pcap is the log of packets that went out from port 1 of switch s1. Likewise, this means that it is the log of packets received by host h1.

Similarly, s1-eth2 and eth3 mean communication of hosts h2 and h3, respectively. How to view the contents of these log files will be explained in the next step.

Quite detailed switch behavior is recorded in bmv2-s1-log, but the details are not explained in this tutorial.

### P4Runtime Shell

#### Creating a working directory and copying files

Create the /tmp/P4Runtime-protoswitch directory for work, and copy the P4 program groups in this tutorial.

```bash
$ mkdir /tmp/P4Runtime-protoswitch
$ cp -r proto0* /tmp/P4Runtime-protoswitch 
$ ls /tmp/P4Runtime-protoswitch
proto01	proto02	proto03
$
```

#### Starting P4Runtime Shell and connecting to Mininet

In this state, start P4 Runtime Shell as follows. Specify the switch program to be sent into Mininet at startup. Note that p4info.txtpb and proto01.json, which should exist under /tmp/proto01 as seen from the docker container, are given as options as the switch program to be sent.

```bash
$ docker run -ti -v /tmp/P4runtime-protoswitch:/tmp p4lang/p4runtime-sh --grpc-addr host.docker.internal:50001 --device-id 1 --election-id 0,1 --config /tmp/proto01/p4info.txtpb,/tmp/proto01/proto01.json
*** Welcome to the IPython shell for P4Runtime ***
P4Runtime sh >>>
```

##### Notes for ARM Mac version

If you got an error such as **"no matching manifest for linux/arm64/v8 in the manifest list entries"** or **"WARNING: The requested image's platform (linux/amd64) does not match ..."** in the above operation, are you using a Mac with an ARM processor? (Depending on the Docker version, more messages than those shown below may be displayed, such as "Run 'docker run --help' for more information", but the important part is **"no matching manifest for linux/arm64/v8"**.)

```bash
$ docker run -ti -v /tmp/P4runtime-protoswitch:/tmp p4lang/p4runtime-sh ....
....(snip)
docker: Error response from daemon: no matching manifest for linux/arm64/v8 in the manifest list entries: no match for platform in manifest: not found
$
```

To run P4C (and P4 Runtime Shell) on an ARM-based Mac, it is currently necessary to enable Rosetta. Check "Use Rosetta for x86_64/amd64 emulation on Apple Silicon" in Dockerhub Settings >> General >> Virtual Machine Options. After that, it is probably good to add the platform option to the docker command, such as `$ docker run --platform=linux/amd64 ...`.

#### When the target is not a local Docker container

If you are using a physical switch that supports P4Runtime (such as Tofino + Barefoot SDE), or a Mininet container running on another machine, specify the target using its IP address instead of host.docker.internal, such as `--grpc-addr 192.168.1.2:50001`.

When using a Docker container on the local host, host.docker.internal can be used, so this tutorial uses that notation.

#### When the connection to the switch is lost

During experiments, messages such as the following may appear. This occurs when Mininet is terminated while connected with P4Runtime Shell, or when the network connection is lost for some reason.

```bash
P4Runtime sh >>> CRITICAL:root:StreamChannel error, closing stream
CRITICAL:root:P4Runtime RPC error (UNAVAILABLE): Socket closed
```

If this message is displayed, exit P4Runtime Shell once and reconnect to Mininet again. Otherwise, operations on the switch will not work.

P4Runtime shell can be exited with the exit command.

```
P4Runtime sh >>> exit
$
```


Now the environment is ready to send and receive packets. Let us proceed to the next step.

## Next Step

Tutorial 1: [The simplest switch](t1_port2port.md)
