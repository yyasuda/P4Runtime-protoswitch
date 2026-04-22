## Tutorial 1: The Simplest Switch

Here, it is assumed that you have already completed [Tutorial 0](t0_prepare.md), and that the compilation of the `port2port.p4` switch program, the startup of Mininet, and the connection from P4Runtime Shell to Mininet have all already been completed.

### Communication Experiment

On the Mininet side, let us try sending a ping from h1 to h2 as follows.

```bash
mininet> h1 ping -c 1 h2 
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=12.4 ms

--- 10.0.0.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 12.384/12.384/12.384/0.000 ms
mininet> s1 ls -l /tmp
total 36
-rw-r--r-- 1 root root    5 Apr 19 06:48 bmv2-s1-grpc-port
-rw-r--r-- 1 root root 4645 Apr 19 06:48 bmv2-s1-log
-rw-r--r-- 1 root root 1095 Apr 19 06:48 bmv2-s1-netcfg.json
-rw-r--r-- 1 root root   32 Apr 19 06:48 bmv2-s1-watchdog.out
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth1_in.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth1_out.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth2_in.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth2_out.pcap
-rw-r--r-- 1 root root    0 Apr 19 06:48 s1-eth3_in.pcap
-rw-r--r-- 1 root root    0 Apr 19 06:48 s1-eth3_out.pcap
mininet>
```

The `mininet> h1 ping -c 1 h2` shown above means that `ping -c 1 h2` is being executed on host h1, that is, a ping is being sent toward h2 only once. The reply arrived in 12.4 ms.

If you check the sizes of the log files after executing ping, you can see that logs have been written to ports eth1 and eth2, which are connected to h1 and h2, and that the file sizes have increased.

#### Checking the logs

Let us look at the contents of each log file.

```bash
mininet> s1 tcpdump -n -r s1-eth1_in.pcap 
reading from file s1-eth1_in.pcap, link-type EN10MB (Ethernet), snapshot length 262144
06:48:51.979680 IP 10.0.0.1 > 10.0.0.2: ICMP echo request, id 105, seq 1, length 64
mininet> s1 tcpdump -n -r s1-eth1_out.pcap 
reading from file s1-eth1_out.pcap, link-type EN10MB (Ethernet), snapshot length 262144
06:48:51.991974 IP 10.0.0.2 > 10.0.0.1: ICMP echo reply, id 105, seq 1, length 64
mininet> s1 tcpdump -n -r s1-eth2_in.pcap 
reading from file s1-eth2_in.pcap, link-type EN10MB (Ethernet), snapshot length 262144
06:48:51.991650 IP 10.0.0.2 > 10.0.0.1: ICMP echo reply, id 105, seq 1, length 64
mininet> s1 tcpdump -n -r s1-eth2_out.pcap 
reading from file s1-eth2_out.pcap, link-type EN10MB (Ethernet), snapshot length 262144
06:48:51.991104 IP 10.0.0.1 > 10.0.0.2: ICMP echo request, id 105, seq 1, length 64
mininet> 
```

Since they were shown in file-name order, it is hard to grasp the contents. Let us rearrange and format the results in timestamp order.

```bash
eth1_in  06:48:51.979680 IP 10.0.0.1 > 10.0.0.2: ICMP echo request
eth2_out 06:48:51.991104 IP 10.0.0.1 > 10.0.0.2: ICMP echo request
eth2_in  06:48:51.991650 IP 10.0.0.2 > 10.0.0.1: ICMP echo reply
eth1_out 06:48:51.991974 IP 10.0.0.2 > 10.0.0.1: ICMP echo reply
```

From this, can you see that packets moved as follows?

1. An ICMP echo request packet (sent out from h1) entered port eth1 of s1.
2. This packet was output (forwarded) from port eth2 of s1 (and as a result reached h2).
3. An ICMP echo response packet (the reply sent out by h2 in response) entered port eth2 of s1.
4. This packet was output (forwarded) from port eth1 of s1 (and as a result reached h1).

### Contents of the `port2port.p4` Program

Such packet forwarding took place because that kind of packet control is written in the switch program sent to the Mininet switch. Let us examine the contents of the P4 program.

#### Overall structure

If you look at the contents of `port2port.p4`, you can see that it has the following structure.

````c++
#include <core.p4>
#include <v1model.p4>

parser MyParser(.....) { }   
control MyVerifyChecksum(.....) { }
control MyIngress(.....) { }

....(snip)

V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
````

In this tutorial, all switch programs are written in this style called V1Model. Each time one packet comes in, that packet is processed by each function written inside `V1Switch()` (almost in the order in which they are written). For detailed architecture and description style, please refer to [P4.org](https://p4.org), the [specification](https://github.com/p4lang/p4-spec), and [various community documents](https://forum.p4.org/t/p4-architecture/246/2). For now, it is enough to think that if the programmer writes the desired functions in a callback-like manner, the switch will call them in accordance with packet arrival.

#### Forwarding processing

In `port2port.p4`, the packet is written so as to pass through without any processing in almost all processing stages prepared by V1Model. The only place where meaningful processing is written is the `MyIngress()` function.

```c++
control MyIngress(inout headers hdr, inout metadata meta,
                    inout standard_metadata_t standard_metadata)
{
    apply {
        if (standard_metadata.ingress_port == 1) {
            standard_metadata.egress_spec = 2;
        } else if (standard_metadata.ingress_port == 2) {
            standard_metadata.egress_spec = 1;
        } else {
            mark_to_drop(standard_metadata);
        }
    }
}
```

When a packet arrives at the switch, a structure variable `standard_metadata` is set for each packet. For example, `standard_metadata.ingress_port` is set to the number of the port through which the packet currently being processed entered. This `standard_metadata` is given as the third argument to the `MyIngress()` function. For other member variables of the `standard_metadata` structure, please refer to the [specification (implementation description)](https://github.com/p4lang/p4c/blob/39e5c45bbb52abdc72b7e842115e61520371f0fc/p4include/v1model.p4#L63).

A V1Model switch ultimately outputs the packet from the port specified by the value set in `standard_metadata.egress_spec`. In other words, for all packets, this program outputs the packet from port 2 if the port it entered was port 1, and outputs it from port 1 if the port it entered was port 2.

If the port through which the packet entered is neither 1 nor 2, instead of specifying an output port, the program sets the packet to the dropped state (not output anywhere) by the `mark_to_drop()` function.

As an experiment, let us send a ping from h3 to h1 in Mininet. You will see that no reply comes back from h1, and if you look at the logs, only `s1-eth3_in.pcap`, which is connected to h3, increases, while nothing is recorded in the other logs (their byte counts do not increase).

```bash
mininet> s1 ls -l       <<< Check the size of the log files before the experiment
total 36
-rw-r--r-- 1 root root    5 Apr 19 06:48 bmv2-s1-grpc-port
-rw-r--r-- 1 root root 4645 Apr 19 06:48 bmv2-s1-log
-rw-r--r-- 1 root root 1095 Apr 19 06:48 bmv2-s1-netcfg.json
-rw-r--r-- 1 root root   32 Apr 19 06:48 bmv2-s1-watchdog.out
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth1_in.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth1_out.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth2_in.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth2_out.pcap
-rw-r--r-- 1 root root    0 Apr 19 06:48 s1-eth3_in.pcap
-rw-r--r-- 1 root root    0 Apr 19 06:48 s1-eth3_out.pcap
mininet> h3 ping -c 1 h1             <<< Send a ping from h3 to h1
PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.

--- 10.0.0.1 ping statistics ---
1 packets transmitted, 0 received, 100% packet loss, time 1ms

mininet> s1 ls -l       <<< Check the size of the log files after the experiment
total 40
-rw-r--r-- 1 root root    5 Apr 19 06:48 bmv2-s1-grpc-port
-rw-r--r-- 1 root root 5877 Apr 19 07:39 bmv2-s1-log
-rw-r--r-- 1 root root 1095 Apr 19 06:48 bmv2-s1-netcfg.json
-rw-r--r-- 1 root root   32 Apr 19 06:48 bmv2-s1-watchdog.out
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth1_in.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth1_out.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth2_in.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth2_out.pcap
-rw-r--r-- 1 root root  138 Apr 19 07:39 s1-eth3_in.pcap  <<< Only this one has increased
-rw-r--r-- 1 root root    0 Apr 19 06:48 s1-eth3_out.pcap
mininet> s1 tcpdump -n -r s1-eth3_in.pcap                 <<< Check the contents
reading from file s1-eth3_in.pcap, link-type EN10MB (Ethernet), snapshot length 262144
07:39:20.276867 IP 10.0.0.3 > 10.0.0.1: ICMP echo request, id 122, seq 1, length 64
mininet> 
```



Next, we will try packet header analysis (parsing), which is necessary for switches and routers.

## Next Step

#### Tutorial 2: [Header Parsing (Interpretation)](t2_macaddr.md)
