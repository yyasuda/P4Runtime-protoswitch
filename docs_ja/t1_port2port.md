## Tutorial 1: 最も単純なスイッチ

ここでは、[Tutorial 0](t0_prepare.md) をすでに終え、port2port.p4 スイッチプログラムのコンパイル、Mininet の起動、P4 Runtime Shell から Mininet への接続までが済んでいることを前提としています。

### 通信実験

Mininet 側で以下のようにして h1 から h2 に向けて ping を掛けてみましょう。

```bash
mininet> h1 ping -c 1 h2 
PING 10.0.0.2 (10.0.0.2) 56(84) bytes of data.
64 bytes from 10.0.0.2: icmp_seq=1 ttl=64 time=12.4 ms

--- 10.0.0.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 12.384/12.384/12.384/0.000 ms
mininet> 
```

上に示した ```mininet> h1 ping -c 1 h2 ``` は、ホスト h1 上で ```ping -c 1 h2``` を、つまり一度だけ h2 に向けた ping を行っているのです。12.4m秒で返事が届いていますね。

/tmp ディレクトリ以下には各種のログが出力されています。

```bash
mininet> sh ls -l /tmp
total 36
-rw-r--r-- 1 root root    5 Apr 24 05:54 bmv2-s1-grpc-port
-rw-r--r-- 1 root root 4657 Apr 24 05:56 bmv2-s1-log
-rw-r--r-- 1 root root 1095 Apr 24 05:54 bmv2-s1-netcfg.json
-rw-r--r-- 1 root root   32 Apr 24 05:54 bmv2-s1-watchdog.out
-rw-r--r-- 1 root root  138 Apr 24 05:56 s1-eth1_in.pcap
-rw-r--r-- 1 root root  138 Apr 24 05:56 s1-eth1_out.pcap
-rw-r--r-- 1 root root  138 Apr 24 05:56 s1-eth2_in.pcap
-rw-r--r-- 1 root root  138 Apr 24 05:56 s1-eth2_out.pcap
-rw-r--r-- 1 root root    0 Apr 24 05:54 s1-eth3_in.pcap
-rw-r--r-- 1 root root    0 Apr 24 05:54 s1-eth3_out.pcap
mininet>
```

bmv2-s1-log にはかなり細かなスイッチの挙動が記録されています。このチュートリアルでは詳細については説明しません。ping 実験の後にファイルサイズを確認すると、上記のように h1, h2 に接続されたポートである s1-eth1, s1-eth2 にログが書き込まれてファイルサイズが増えていることがわかります。

#### ログの確認

s1-eth1_in.pcap ファイルの中身を見てみましょう。

```bash
mininet> sh tcpdump -n -r s1-eth1_in.pcap 
reading from file s1-eth1_in.pcap, link-type EN10MB (Ethernet), snapshot length 262144
06:48:51.979680 IP 10.0.0.1 > 10.0.0.2: ICMP echo request, id 105, seq 1, length 64
mininet> 
```

すべての pcap ログファイルについて上記の方法で内容を表示させ、それをタイムスタンプ順に並べるシェルスクリプト、dump_pcaps を用意しています。以下のようにして実行できます。

```bash
mininet> sh dump_pcaps
eth1_in  5:56:56.595130 IP 10.0.0.1 > 10.0.0.2: ICMP echo request, id 108, seq 1, length 64
eth2_out 5:56:56.597296 IP 10.0.0.1 > 10.0.0.2: ICMP echo request, id 108, seq 1, length 64
eth2_in  5:56:56.598175 IP 10.0.0.2 > 10.0.0.1: ICMP echo reply, id 108, seq 1, length 64
eth1_out 5:56:56.598834 IP 10.0.0.2 > 10.0.0.1: ICMP echo reply, id 108, seq 1, length 64
mininet> 
```

これで以下のようなパケットの動きがあったことが分かるでしょうか。

1. （h1 から送り出された） ICMP echo request パケットが s1 の eth1 ポートに入ってきた
2. このパケットは s1 の eth2 ポートから出力（転送）された（その結果 h2 に届いた）
3. （h2 がそれに反応して送り出された返事である） ICMP echo response パケットを s1 の eth2 ポートに入ってきた
4. このパケットは s1 の eth1 ポートから出力（転送）された（その結果 h1 に届いた）


### port2port.p4 プログラムの内容

このようなパケットの転送が行われたのは、Mininet のスイッチに送り込まれたスイッチプログラムにそのようなパケット制御が書かれているからです。P4プログラムの内容を確認しましょう。

#### 全体構造

port2port.p4 の中身を見ると、以下のような構造をしていることがわかります。

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

このチュートリアルでは、すべてのスイッチプログラムをこの V1Model と呼ばれる書き方で記述します。パケットが一つ入ってくるたびに、そのパケットは V1Switch( ) 内に書かれた各関数によって（ほぼその記述順に）処理されます。細かなアーキテクチャや記述方式については[P4.org](https://p4.org)、[仕様](https://github.com/p4lang/p4-spec)や[各種コミュニティ文書など](https://forum.p4.org/t/p4-architecture/246/2)を見てもらうとして、プログラマは自分の望む機能を Callback 関数的に記述していけば、パケットの到来に合わせてスイッチ内で呼び出してくれる、と考えておけば良いです。

#### 転送処理

port2port.p4 は V1Model が用意したほとんどの処理段階で、パケットには何の処理もしないまま通過させるように書かれています。唯一、意味のある処理が書かれているのは MyIngress( ) 関数です。

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

パケットがスイッチに到着すると、パケット一つ一つに構造体変数 standard_metadata がセットされます。例えば standard_metadata.ingress_port には今処理しているパケットが入ってきたポートの番号がセットされています。この standard_metadata は、MyIngress( ) 関数の第3引数として与えられています。standard_metadata 構造体の他のメンバ変数については [仕様（実装記述）](https://github.com/p4lang/p4c/blob/39e5c45bbb52abdc72b7e842115e61520371f0fc/p4include/v1model.p4#L63) を見てください。

V1Model のスイッチは最終的に standard_metadata.egress_spec にセットされている値に従って、指定のポートからパケットを出力します。つまりこのプログラムはすべてのパケットについて、それが入ってきたポートが 1 だった場合はポート 2 から出力し、入ってきたポートが 2 だったらポート 1 から出力するのです。

もしパケットが入ってきたポートが 1 でも 2 でもない場合、プログラムは出力先ポートを指定する代わりに mark_to_drop( ) 関数によってドロップ（どこにも出力されない）状態にセットします。

試しに Mininet で h3 から h1 あてに ping を出してみましょう。返事は h1 から返ってこず、ログを見ても h3 に繋がれた s1-eth3_in.pcap だけが増えて、それ以外のログには何も記録されていない（バイト数が増えない）ことが分かるでしょう。

```bash
mininet> sh ls -l                    <<< 実験前のログファイルの容量を確認
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
mininet> h3 ping -c 1 h1             <<< h3 から h1 宛の ping を発行 
PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.

--- 10.0.0.1 ping statistics ---
1 packets transmitted, 0 received, 100% packet loss, time 1ms

mininet> sh ls -l                    <<< 実験後のログファイルの容量をチェック
total 40
-rw-r--r-- 1 root root    5 Apr 19 06:48 bmv2-s1-grpc-port
-rw-r--r-- 1 root root 5877 Apr 19 07:39 bmv2-s1-log
-rw-r--r-- 1 root root 1095 Apr 19 06:48 bmv2-s1-netcfg.json
-rw-r--r-- 1 root root   32 Apr 19 06:48 bmv2-s1-watchdog.out
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth1_in.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth1_out.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth2_in.pcap
-rw-r--r-- 1 root root  138 Apr 19 06:48 s1-eth2_out.pcap
-rw-r--r-- 1 root root  138 Apr 19 07:39 s1-eth3_in.pcap  <<< ここだけが増えている
-rw-r--r-- 1 root root    0 Apr 19 06:48 s1-eth3_out.pcap
mininet> sh tcpdump -n -r s1-eth3_in.pcap                 <<< 内容を確認
reading from file s1-eth3_in.pcap, link-type EN10MB (Ethernet), snapshot length 262144
07:39:20.276867 IP 10.0.0.3 > 10.0.0.1: ICMP echo request, id 122, seq 1, length 64
mininet> 
```



次はスイッチやルータに必要なパケットヘッダの解析（パース）処理を試します。


## Next Step

#### Tutorial 2: [ヘッダのパース（解釈）](t2_macaddr.md)

