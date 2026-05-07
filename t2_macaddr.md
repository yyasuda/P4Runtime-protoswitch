## Tutorial 2: Header parsing (Interpretation)

In general, switches and routers determine forwarding destinations according to information contained in packet headers. In other words, it is necessary to interpret (parse) each field in the packet header. Here, we perform header parsing and try the switch program `proto02.p4`, which determines the forwarding destination according to the MAC address.

### Changing the switch program

In Tutorial 1, the switch was operated by giving Mininet the switch program compiled from `proto01.p4`. Change this to `proto02.p4` using the following procedure.

1. Exit P4Runtime Shell once
2. Restart P4Runtime Shell using `proto02.p4`, and send the program into Mininet

Mininet continues running without being terminated, so logs continue to be added. If old log data is unnecessary for a new experiment, it is probably good to restart Mininet between steps 1 and 2 above.

Only the command sequence is shown below.

1. Exit P4Runtime Shell

```bash
P4Runtime sh >>> exit
$
```

2. Restart P4Runtime Shell

```bash
$ docker run -ti -v /tmp/P4runtime-protoswitch:/tmp p4lang/p4runtime-sh --grpc-addr host.docker.internal:50001 --device-id 1 --election-id 0,1 --config /tmp/proto02/p4info.txtpb,/tmp/proto02/proto02.json
....
P4Runtime sh >>>
```

### Communication experiment

On the Mininet side, try sending a ping from h1 to h2 as follows.

```bash
mininet> h1 ping -c 1 h2 
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=11.0 ms

--- 10.0.0.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 10.980/10.980/10.980/0.000 ms
mininet> 
```

If you examine the log files, you will observe that packets are forwarded in exactly the same way as in Tutorial 0.

### Contents of the `proto02.p4` program

Such packet forwarding took place because such packet forwarding control is written in the switch program sent to the Mininet switch. Let us examine the contents of the P4 program.

#### Header definitions and parser

Compared to `proto01.p4`, definitions of packet headers have been added at the beginning. Structure variables corresponding to the Ethernet header and IPv4 header are written (note that the type name is `header`, not `struct`).

Following that, processing is described inside the `MyParser()` function to map these header definitions onto the packet. Such parsing processing is sometimes written as a state machine, and in P4 it is indeed described as definitions of states such as `state xxxx { ... }`.

When a packet enters the switch, the `MyParser()` function is called, and the initial state is `start`. This is defined as `state start { ... }`, and it is written that it transitions unconditionally to the `parse_ethernet` state. As parsing proceeds, contents are extracted into header structure variables by `extract()`, and depending on the values, it transitions to appropriate next states, eventually reaching `accept` and terminating.

```c++
/ --- headers ---
header ethernet_t {            <<<< Definition of Ethernet header
    ....(snip)
}

header ipv4_t {                <<<< Definition of IP header
    ....(snip)
}

struct headers {               <<<< Structures used as headers are members of headers
    ethernet_t ethernet;
    ipv4_t     ipv4;
}

//     Prepare state-transition-like code as a parser to interpret Ethernet and IP headers
parser MyParser(packet_in packet, out headers hdr, inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        transition parse_ethernet;  <<<< Unconditionally transition to parse_ethernet
    }
    state parse_ethernet {             <<<< parse_ethernet state
        packet.extract(hdr.ethernet);  <<<< Extract Ethernet header
        transition select(hdr.ethernet.etherType) {  <<<< Select next state based on protocol type
            ETHERTYPE_IPV4: parse_ipv4;   <<<< If IPv4, transition to parse_ipv4
            default: accept;              <<<< Otherwise, end parsing here
        }
    }
    state parse_ipv4 {                <<<< parse_ipv4 state
        packet.extract(hdr.ipv4);     <<<< Extract IP header
        transition accept;            <<<< End parsing here
    }
}
```

#### Ingress processing

When parsing processing finishes, the `MyIngress()` function is called. In `proto01.p4`, the forwarding destination was set using the input port information in `standard_metadata`, but in `proto02.p4`, the forwarding destination is set according to the value of the `dstAddr` member of the `ethernet` structure extracted by parsing processing, that is, the destination MAC address.

```c++
control MyIngress(inout headers hdr, inout metadata meta,
                    inout standard_metadata_t standard_metadata) {
    const macAddr_t MAC1 = 0x000000000001;
    const macAddr_t MAC2 = 0x000000000002;

    const egressSpec_t PORT1 = 1;
    const egressSpec_t PORT2 = 2;

    apply {
        if (hdr.ethernet.dstAddr == MAC1) {
            standard_metadata.egress_spec = PORT1;
        } else if (hdr.ethernet.dstAddr == MAC2) {
            standard_metadata.egress_spec = PORT2;
        } else {
            mark_to_drop(standard_metadata);
        }
    }
}
```

#### Deparser processing

Looking at the subsequent `MyDeparser()` function, the `emit()` function is executed. This is one of the somewhat tricky notations in P4 and requires some explanation.

In P4, a packet that enters the switch is divided into a “header” and a “body” during parsing. The header is extracted into several structure variables that are members of `headers`, and thereafter they are referenced and updated by their variable names (e.g., `hdr.ethernet.dstAddr`) in the P4 program. On the other hand, the body is stored in the switch buffer and is finally combined with the (possibly modified) header and output as a single packet. The portion extracted by `extract()` in the parser becomes the header, and the portion not extracted at the point of `accept()` is treated as the body.

Therefore, in the `MyDeparser()` function, the headers (structure variables) that should be output together with the body are written to be passed to the `emit()` function as follows.

```c++
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}
```

However, in the `MyParser()` processing, if the incoming packet is IPv4, both `hdr.ethernet` and `hdr.ipv4` are extracted, but if it is not an IPv4 packet, only `hdr.ethernet` is extracted. In that case, it might seem that `hdr.ipv4` should not be emitted. However, there is an interesting mechanism here, explained below.

1. Each header variable has an attribute called Valid  
2. The initial value is Invalid, but it is automatically set to Valid when `extract()` is performed during parsing  
3. The programmer can also set it arbitrarily in Ingress processing using functions such as `hdr.ethernet.setValid()` and `setInvalid()`  
4. In Deparser processing, `emit()` outputs the header together with the body if the specified header variable is Valid, but does nothing if it is Invalid  

In other words, in Deparser processing, it is sufficient to `emit()` all headers that may be extracted.

##### You cannot write it like this

You can also check the Valid state using the `isValid()` function. You might think it would be better if the following could be written, but writing it like this in Deparser processing results in an error.

```c++
    apply {
        packet.emit(hdr.ethernet);
        if (hdr.ipv4.isValid()) {
            packet.emit(hdr.ipv4);
        }
    }
```



## Next Step

#### Tutorial 3: [Adding entries to a table](t3_add_entry.md)
