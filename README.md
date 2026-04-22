# P4Runtime-protoswitch

An ultimately primitive P4Runtime tutorial for beginners in P4.

## Introduction

The code and data in this repository were created as a tutorial to provide a simple entry point for those who want to try controlling a P4 switch using P4Runtime for the first time. It assumes that the reader has some basic understanding of P4 and P4Runtime. It is intended to serve as a good starting point for those who are trying it hands-on for the first time.

## This tutorial does…

This tutorial performs the following three experiments:

- Packet forwarding using only input port information
- Packet forwarding based on destination MAC address
- Packet forwarding using match-action tables

These experiments are conducted in the following environment:

- P4Runtime Shell is used as the controller
- A P4Runtime-enabled Mininet is used as the switch
- The open-source p4c is used for P4 compilation

All of these are prepared to run in a Docker environment. At first, please use exactly what is described in this document.

## Tools

All experiments in this tutorial are performed in a Docker environment.

#### P4C

Docker Hub: [p4lang/p4c](https://hub.docker.com/r/p4lang/p4c) 

#### P4Runtime-enabled Mininet Docker Image (modified)

Docker Hub: [yutakayasuda/p4mn](https://hub.docker.com/r/yutakayasuda/p4mn) 
GitHub: [opennetworkinglab/p4mn-docker](https://github.com/opennetworkinglab/p4mn-docker)

The original [opennetworking/p4mn](https://hub.docker.com/r/opennetworking/p4mn) also works almost the same, but since handling logs was not very convenient, a modified version was created.

#### P4Runtime Shell

Docker Hub:  [P4Runtime Shell](https://hub.docker.com/r/p4lang/p4runtime-sh)
GitHub: [yyasuda/p4runtime-shell](https://github.com/yyasuda/p4runtime-shell)

## Step by Step

The steps are shown below. It is recommended to try them in order.

### Tutorial 0: Preparation of the experimental environment

Before starting the experiments, you need to compile the P4 switch program. Then, start Mininet and connect the P4Runtime Shell, which acts as the controller.

### Tutorial 1: The simplest switch

We perform a forwarding experiment using an extremely simple switch program, port2port.p4, which simply forwards packets entering port 1 to port 2, and packets entering port 2 to port 1.

### Tutorial 2: Header parsing (interpretation)

Here, we parse (interpret) headers and use a switch program, macaddr.p4, that determines the forwarding destination based on the extracted destination MAC address field.

### Tutorial 3: Adding entries to a table

P4 has something called a Match-Action Table, which allows applying necessary processing (actions) per packet. Here, we use a switch program, tablematch.p4, where the forwarding destination is determined by a table keyed by destination MAC address.

## Next Step

This tutorial focuses on providing an easy-to-understand entry point without touching the internal structure. The next step would be to use this as a starting point and dig deeper into the internals. Below are some documents that I found particularly useful.

- [P4Runtime Specification](https://p4.org/specifications/) v1.5.0 [[HTML](https://p4lang.github.io/p4runtime/spec/v1.5.0/P4Runtime-Spec.html)] [[PDF](https://p4lang.github.io/p4runtime/spec/v1.5.0/P4Runtime-Spec.pdf)]
- P4Runtime proto p4/v1/[p4runtime.proto](https://github.com/p4lang/p4runtime/blob/master/proto/p4/v1/p4runtime.proto) 
- P4Runtime proto p4/config/v1/[p4info.proto](https://github.com/p4lang/p4runtime/blob/master/proto/p4/config/v1/p4info.proto) 
- [P4<sub>16</sub> Portable Switch Architecture (PSA)](https://p4.org/specifications/) v1.2 [[HTML](https://p4.org/wp-content/uploads/sites/53/p4-spec/docs/PSA-v1.2.html)] [[PDF](https://p4.org/wp-content/uploads/sites/53/p4-spec/docs/PSA-v1.2.pdf)]
  In the P4Runtime Specification above, descriptions such as “1.2 In Scope” suggest that P4Runtime assumes PSA to some extent. Although it was not directly relevant in this tutorial, it may be useful to read if you encounter descriptions that concern you.



