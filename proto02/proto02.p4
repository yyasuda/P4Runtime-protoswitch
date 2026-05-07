#include <core.p4>
#include <v1model.p4>

// --- typedef ---
typedef bit<9>  egressSpec_t;
typedef bit<48> macAddr_t;
typedef bit<32> ip4Addr_t;

const bit<16> ETHERTYPE_IPV4 = 0x0800;

// --- headers ---
header ethernet_t {
    macAddr_t dstAddr;
    macAddr_t srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    ip4Addr_t srcAddr;
    ip4Addr_t dstAddr;
}

struct headers {
    ethernet_t ethernet;
    ipv4_t     ipv4;
}

struct metadata {
}

// --- parser ---
parser MyParser(packet_in packet, out headers hdr, inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            ETHERTYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition accept;
    }
}

// --- controls ---
control MyVerifyChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

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

control MyEgress(inout headers hdr, inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    apply { }
}

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply { }
}

control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}

// --- switch ---
V1Switch(
    MyParser(),
    MyVerifyChecksum(),
    MyIngress(),
    MyEgress(),
    MyComputeChecksum(),
    MyDeparser()
) main;
