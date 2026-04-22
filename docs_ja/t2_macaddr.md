## Tutorial 2: ヘッダのパース（解釈）

一般にスイッチやルータはパケットのヘッダの中にある情報によって転送先を決定します。つまりパケットヘッダの各フィールドを解釈（パース）する必要があります。ここではヘッダのパースを行い、MACアドレスによって転送先を決定するスイッチプログラム、macaddr.p4 を試します。

### スイッチプログラムの切り替え

Tutorial 1 ではスイッチに port2port.p4 をコンパイルしたスイッチプログラムを Mininet に与えて動かしていました。以下の手順でこれを macaddr.p4 に変更します。
1. P4C コンテナで macaddr.p4 をコンパイルする
2. P4Runtime Shell を一度終了する
3. P4Runtime Shell を 1. で生成したファイルを用いて再起動し、Mininet にプログラムを送り込む

Mininet は終了せず実行を継続していますので、ログはどんどん追加されていきます。もし新しい実験では古いログデータは不要だ、という場合は、上の手順の 2. と 3. ので Mininet を再起動すると良いでしょう。

以下にコマンド列だけ書いておきます。

1. macaddr.p4 のコンパイル
```bash
$ docker run -it -v /tmp/P4Runtime-protoswitch/:/tmp/ p4lang/p4c:1.2.5.6 /bin/bash
root@d5da54abaa97:/p4c# cd /tmp
root@d5da54abaa97:/tmp# p4c --target bmv2 --arch v1model --p4runtime-files macaddr_p4info.txtpb macaddr.p4 
root@d5da54abaa97:/tmp# 
```

2. P4Runtime Shell 終了
```bash
P4Runtime sh >>> exit
$
```

3. P4Runtime Shell 再起動
```bash
$ docker run -ti -v /tmp/P4runtime-protoswitch:/tmp p4lang/p4runtime-sh --grpc-addr host.docker.internal:50001 --device-id 1 --election-id 0,1 --config /tmp/macaddr_p4info.txtpb,/tmp/macaddr.json
....
P4Runtime sh >>>
```

### 通信実験

Mininet 側で以下のようにして h1 から h2 に向けて ping を掛けてみましょう。

```bash
mininet> h1 ping -c 1 h2 
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=11.0 ms

--- 10.0.0.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 10.980/10.980/10.980/0.000 ms
mininet> 
```

ログファイルを調べてみると、Tutorial 0 とまったく同じように転送されていることが観察できると思います。

### macaddr.p4 プログラムの内容

このようなパケットの転送が行われたのは、Mininet のスイッチに送り込まれたスイッチプログラムにそのようなパケット制御が書かれているからです。P4プログラムの内容を確認しましょう。

#### ヘッダ定義とパーサ

port2port.p4 に対して、冒頭にパケットヘッダの定義が追加されました。Ethernet ヘッダと IPv4 ヘッダに対応する構造体変数が書かれています。（ただし型名は struct ではなく header）

それに続いて MyParser( ) 関数の中に、このヘッダ定義を当てはめていく処理が記述されました。こうしたパース処理は状態機械（state machine）として書かれることがありますが、P4 ではまさに state xxxx { .... } として状態の定義を記述しています。

パケットがスイッチに入ってくると MyParser( ) 関数が呼び出され、初期状態は start です。これは state start { .... } で定義されており、無条件に parse_ethernet 状態に遷移する（transition）と書かれています。パース処理は段階を進むにつれて extract( ) によってヘッダ構造体変数に内容を取り出し、その値によって適した遷移先へ進み、どこかの段階で accept となって終了する、といった動きをします。

````c++
/ --- headers ---
header ethernet_t {            <<<< Ethernet Header の定義
    ....(snip)
}

header ipv4_t {                <<<< IP Header の定義
    ....(snip)
}

struct headers {               <<<< ヘッダとして使った構造体は headers のメンバにする
    ethernet_t ethernet;
    ipv4_t     ipv4;
}

//     パーサとして上の Ethernet, IP header を解釈するための状態遷移的コードを用意
parser MyParser(packet_in packet, out headers hdr, inout metadata meta,
                inout standard_metadata_t standard_metadata) {
    state start {
        transition parse_ethernet;  <<<< 無条件に parse_ethernet 状態に遷移
    }
    state parse_ethernet {             <<<< parse_ethernet 状態
        packet.extract(hdr.ethernet);  <<<< Ethernet ヘッダを取り出し
        transition select(hdr.ethernet.etherType) {  <<<< プロトコルタイプによって遷移先を選択
            ETHERTYPE_IPV4: parse_ipv4;   <<<< IPv4 であれば parse_ipv4 状態に遷移
            default: accept;              <<<< それ以外であればこの時点でパース処理を終了
        }
    }
    state parse_ipv4 {                <<<< parse_ipv4 状態
        packet.extract(hdr.ipv4);     <<<< ip ヘッダを取り出し
        transition accept;            <<<< ここでパース処理を終了
    }
}
````

#### Ingress 処理

パース処理が終わると、MyIngress( ) 関数が呼ばれます。port2port.p4 では standard_metadata の入力ポート情報で送出先を設定していましたが、macaddr.p4 ではパース処理で取り出した ethernet 構造体の dstAddr メンバ、つまり宛先 MAC アドレスの値によって送信先が設定されます。

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

#### Deparser 処理

そして後段の MyDeparser( ) 関数を見ると emit( ) 関数が実行されています。ここは P4 による変則的な記述の一つで、幾らか説明が必要です。

P4 ではスイッチに入ってきたパケットはパーサ処理で「ヘッダ」と「ボディ」に分けられます。ヘッダは headers のメンバーである構造体変数の幾つかに取り出され、それ以降の P4 プログラムでそれら造体変数の名前（ex. hdr.ethernet.dstAddr）で参照・更新されます。対してボディはスイッチのバッファにためられて、最終的に（一部は加工されたであろう）ヘッダと合体させ、一つのパケットとしてスイッチの外に出力されます。なおパーサ処理で extract( ) された部分までがヘッダとなり、accept( ) された時点で extract( ) されなかった部分がボディとして扱われます。

というわけで、MyParser( ) 関数には extract( ) したヘッダ（構造体変数）のうち、ボディと合わせて出力すべきヘッダを以下のように emit( ) 関数に掛けるよう書かれます。

```bash
control MyDeparser(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
    }
}
```

しかし MyParser( ) 処理では、入ってきたパケットが IPv4 であれば hdr.ethernet と hdr.ipv4 ヘッダ両方に extract( ) されますが、IPv4 パケットでなければ hdr.ethernet ヘッダにしか extract( ) されません。この場合は hdr.ipv4 ヘッダを emit( ) してはいけないように思えます。しかしここには面白い仕組みがあります。以下に説明します。

1. ヘッダ変数にはそれぞれ Valid という属性がある
2. 初期値は Invalid であるが、パース処理で extract( ) することによって自動的に Valid にセットされる
3. Ingres 処理などで hdr.ethernet.setValid( ) や setInvalid( ) などでプログラマが任意に設定することもできる
4. Deparser 処理の emit( ) は、指定されたヘッダ変数が Valid の場合はボディと合わせて出力されるが、 Invalid の場合は何もしない

つまりとにかく Deparser 処理では extract( ) される可能性のあるヘッダについては全部 emit( ) すれば良いようになっています。

##### このような書き方はできません

なお isValid( ) という関数で Valid の状態を調べることもできます。それなら以下のように書かせてくれれば良いのにと思った事もあるのですが、Deparser 処理でこのように書くとエラーになります。


```c++
    apply {
        packet.emit(hdr.ethernet);
        if (hdr.ipv4.isValid()) {
            packet.emit(hdr.ipv4);
        }
    }
```



## Next Step

#### Tutorial 3: [テーブルへのエントリ追加](t3_add_entry.md)

