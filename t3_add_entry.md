## Tutorial 3: Adding entries to a table

In Tutorial 2, the processing for determining the forwarding destination was all hardcoded in the P4 program. However, in general, switches and routers determine forwarding destinations by looking up internally configured tables. Here, we try the switch program `proto03.p4`, which determines the forwarding destination according to the MAC address obtained by parsing.

### Match-Action Table configuration

P4 has something called a Match-Action Table, which allows the necessary processing (actions) to be applied per packet. In this tutorial, we prepare a table as shown below.

<img src="./t3_table.png" alt="attach:(table entry)" title="Table Entry" width="350">

We explain the format of this table. Refer to the `proto02.p4` program (shown later) for variable names and function names.

* The table name is `"dmac_table"`
* Only one key field is prepared, of type `ethernet.dstAddr`
* The action function is set to either `forward()` or `drop()`
* In the above figure, packets destined for `00:00:00:00:00:01` (h1) execute `forward(1)`, and packets destined for `00:00:00:00:00:02` (h2) execute `forward(2)`
* If no key matches, the `drop()` function is executed

### Changing the switch program

As was done in Tutorial 2, this time we run Mininet using the switch program compiled from `proto03.p4`. Below is the result of restarting P4Runtime Shell.

```python
$ docker run -ti -v /tmp/P4runtime-protoswitch:/tmp p4lang/p4runtime-sh --grpc-addr host.docker.internal:50001 --device-id 1 --election-id 0,1 --config /tmp/proto03/p4info.txtpb,/tmp/proto03/proto03.json
*** Welcome to the IPython shell for P4Runtime ***
P4Runtime sh >>>
```

### Table processing

#### Checking existing tables and their definitions

Using the `tables` command, you can check the tables present in the switch, that is, the existence of `dmac_table` defined in the P4 program. By specifying a table by name, you can also check the details of its definition.

```c++
P4Runtime sh >>> tables          <<<< Display the list of existing tables
MyIngress.dmac_table             <<<< dmac_table exists inside MyIngress processing
P4Runtime sh >>> tables["MyIngress.dmac_table"]  <<<< Show details by specifying the name
Out[5]: 
preamble {
  id: 35550025
  name: "MyIngress.dmac_table"
  alias: "dmac_table"
}
match_fields {
  id: 1
  name: "hdr.ethernet.dstAddr"
  bitwidth: 48
  match_type: EXACT
}
action_refs {
  id: 29683729 ("MyIngress.forward")
}
action_refs {
  id: 25652968 ("MyIngress.drop")
}
initial_default_action {
  action_id: 25652968
}
size: 1024

P4Runtime sh >>>
```

#### Inserting entries

Set the key and action for h1 in the table. Set various parameters (destination MAC address `"00:00:00:00:00:01"`, action function forward(1)) into a Table Entry instance (variable name `te`), and simply call `te.insert()`.

```python
P4Runtime sh >>> te = table_entry["MyIngress.dmac_table"](action="MyIngress.forward")

P4Runtime sh >>> te.match["hdr.ethernet.dstAddr"] = "00:00:00:00:00:01"  <<<< Set the key
field_id: 1
exact {
  value: "\001"
}

P4Runtime sh >>> te.action.set(port="1")    <<<< Set 1 to the port argument of the action function
param_id: 1
value: "\001"

P4Runtime sh >>> te.insert()                <<<< Insert the completed table entry

P4Runtime sh >>>
```

The [P4Runtime Shell GitHub repository](https://github.com/p4lang/p4runtime-shell) contains examples of such table operations. It is worth looking at.

##### A slightly different way of writing

In the first line, when creating the `te` instance, the action function is specified as `forward()` in advance, and then the key (MAC address) and the parameter (port number 1) of that action function are set. For those who find it easier to understand to set them in the order of key, action function, and parameters, the following style is also possible.

```python
te = table_entry["MyIngress.dmac_table"]()
te.match["hdr.ethernet.dstAddr"] = "00:00:00:00:00:01"
te.action = Action("MyIngress.forward")
te.action.set(port="1")
te.insert()
```

In other words, specifying `(action="forward")` at the end of the first line automatically creates an instance of the action function and sets it to `te.action`.

#### Displaying table contents

After a successful insert, let us check the contents of the table.

```python
P4Runtime sh >>> table_entry["MyIngress.dmac_table"].read(lambda te: print(te))
table_id: 35550025 ("MyIngress.dmac_table")
match {
  field_id: 1 ("hdr.ethernet.dstAddr")
  exact {
    value: "\\x01"
  }
}
action {
  action {
    action_id: 29683729 ("MyIngress.forward")
    params {
      param_id: 1 ("port")
      value: "\\x01"
    }
  }
}

P4Runtime sh >>>
```

Next, add an entry for h2 in the same way and check its contents. Once two entries have been correctly set, proceed to the next communication Experiment.

### Communication Experiment

On the Mininet side, try sending a ping from h1 to h2 or h3 as follows.

```bash
mininet> h1 ping -c 1 h2                       <<<< h1 -> h2
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=7.24 ms      <<<< Reply received

--- 10.0.0.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 7.242/7.242/7.242/0.000 ms
mininet>

mininet> h1 ping -c 1 h3                       <<<< h1 -> h3
PING 10.0.0.3 (10.0.0.3) 56(84) bytes of data.
^C                                                   <<<< No reply, so interrupted with Control-C
--- 10.0.0.3 ping statistics ---
1 packets transmitted, 0 received, 100% packet loss, time 0ms

mininet>
```

If you examine the log files, you will observe that packets are forwarded correctly. Of course, if you add an entry for h3 to the table, ping from h1 to h3 will also succeed.

### Contents of the `proto03.p4` program

Such packet forwarding took place because such packet forwarding control is written in the switch program sent to the Mininet switch. Let us examine the contents of the P4 program.

#### Table definition

Within the `MyIngress()` function, which is called in the Ingress processing stage, there are descriptions related to table processing (definitions of functions and the table). An excerpt is shown below.

```c++
    action forward(egressSpec_t port) {  <<<< Definition of action function forward()
        standard_metadata.egress_spec = port;   <<<< Set the port as the output target
    }
    action drop() {                              <<<< Definition of action function drop()
        mark_to_drop(standard_metadata);         <<<< Specify drop (not output anywhere)
    }

    table dmac_table {                     <<<< Definition of table "dmac_table"
        key = {
            hdr.ethernet.dstAddr : exact;  <<<< The key is only this ethernet.dstAddr field
        }
        actions = {                 <<<< These two can be specified as action functions
            forward;
            drop;
        }
        size = 1024;
        default_action = drop();    <<<< Default is drop()
    }
```

In this program, the above table-related description occupies most of `MyIngress()`. The actual execution part of `MyIngress()` consists only of `apply { }`, and inside it simply calls the `apply()` function for the table `dmac_table` defined above. If this call is not present and the table is only defined, match-action processing on packets will not occur.

```c++
control MyIngress(inout headers hdr, inout metadata meta,
                    inout standard_metadata_t standard_metadata) {

    ### Definitions related to the table shown above

    apply {    <<<< Actual execution of MyIngress() (not part of the table definition)
        dmac_table.apply();  <<<< Match the input packet against dmac_table
    }
}
```

### Reference: Deleting entries

You could display all registered entries as follows:

```bash
P4Runtime sh >>> table_entry["MyIngress.dmac_table"].read(lambda a: print(a))
```

Similarly, you can delete all registered entries as follows:

```bash
P4Runtime sh >>> table_entry["MyIngress.dmac_table"].read(lambda a: a.delete())
```



This completes the series of tutorials. Good job.

## Next Step

Perhaps next is [here](README.md#next-step).
