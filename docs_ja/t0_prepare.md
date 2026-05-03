## Tutorial 0: 実験環境の準備

このチュートリアルでは Mininet を起動し、そこにコントローラ代わりとなる P4 Runtime Shell を接続させて実験を行います。

### システム構成

今回実験する環境のシステム構成を以下の図に示します。スイッチは Mininet 環境を使って、3 port のものを用意します。P4Runtime Shellをコントローラの役割に使います。

<img src="../t0_structure.png" alt="attach:(system structure)" title="System Structure" width="500">

P4Runtimeではコントローラとスイッチの間をgRPCで接続します。Mininetの起動時にはgRPCで接続するためのポート番号(TCP 5000)を指定します。P4Runtime Shellの起動時には接続対象となるMininet環境のIPアドレスとポート番号を指定します。P4Runtime Shell は起動されると、同様に起動時に指定されたP4プログラムをgRPCのコネクションを通じてスイッチにインストールします。

以下に具体的な手順を示します。

### Mininet 環境の立ち上げ

ここでは [P4Runtime-enabled Mininet Docker Image](https://hub.docker.com/repository/docker/yutakayasuda/p4mn) をスイッチとして利用します。以下のようにして起動すると良いでしょう。

P4Runtimeに対応した Mininet 環境を、Docker環境で起動します。起動時に --arp と --mac オプションを指定して、ARP 処理無しに ping テストなどができるようにしてあることに注意してください。

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

s1 の port 1 が h1 に、port 2 が h2に、port 3 が h3 に接続されていることが確認できます。

```bash
mininet> net
h1 h1-eth0:s1-eth1
h2 h2-eth0:s1-eth2
h3 h3-eth0:s1-eth3
s1 lo:  s1-eth1:h1-eth0 s1-eth2:h2-eth0 s1-eth3:h3-eth0
mininet> 
```

h1 がスイッチにつながれているインタフェイス h1-eth0 の MAC アドレスは  00:00:00:00:00:01です。同様に h2 が 00:00:00:00:00:02、h3 が 00:00:00:00:00:03 です。

#### ログデータ

Mininet 起動時に与えた ```-e LOGLEVEL=debug -e PKTDUMP=true -e ``` オプションによって、Mininet コンテナの /tmp ディレクトリ以下にログファイルができていることがわかるでしょう。なお、Mininet におけるコマンド指示は、最初にホスト名を指定し、その後に指定したホストで実行するコマンドを記述するようになっています。つまり ```mininet> s1 ls -l /tmp``` は、スイッチ（のOS）上で ```ls -l /tmp``` を実行しているのです。

```bash
mininet> s1 ls -l /tmp
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

s1-eth1_in.pcap はスイッチ s1 の 1 番ポートに入ってきたパケットのログです。s1-eth1 に接続されているのは h1-eth0 ですから、これはつまりホスト h1 から送り出されたパケットのログでもあります。

s1-eth1_out.pcap は同じくスイッチ s1 の 1 番ポートから出ていったパケットのログです。同様にこれはつまり、ホスト h1 が受け取ったパケットのログでもあります。

s1-eth2, eth3 についてもそれぞれホスト h2, h3 の通信を意味します。これらのログファイルの中身の見方は次のステップで説明します。

なお bmv2-s1-log にはかなり細かなスイッチの挙動が記録されていますが、このチュートリアルでは詳細について説明しません。

### P4Runtime Shell

#### 作業場所の作成とファイルのコピー

作業用に /tmp/P4Runtime-protoswitch ディレクトリを作り、この Tutorial にある P4 プログラム群をコピーします。

```bash
$ mkdir /tmp/P4Runtime-protoswitch
$ cp -r proto0* /tmp/P4Runtime-protoswitch 
$ ls /tmp/P4Runtime-protoswitch
proto01	proto02	proto03
$
```

#### P4Runtme Shell の起動と Mininet への接続

この状態で以下のようにして P4 Runtime Shell を起動します。起動時に Mininet に送り込むスイッチプログラムを指定します。送り込むべきスイッチプログラムとして、docker コンテナから見て /tmp/proto01 以下にあるはずの p4info.txtpb と proto01.json をオプションに与えていることに注意してください。

```bash
$ docker run -ti -v /tmp/P4runtime-protoswitch:/tmp p4lang/p4runtime-sh --grpc-addr host.docker.internal:50001 --device-id 1 --election-id 0,1 --config /tmp/proto01/p4info.txtpb,/tmp/proto01/proto01.json
*** Welcome to the IPython shell for P4Runtime ***
P4Runtime sh >>>
```

##### ARM Mac 版での注意

上の操作で **"no matching manifest for linux/arm64/v8 in the manifest list entries"** あるいは **"WARNING: The requested image's platform (linux/amd64) does not match ..."** といったエラーが出た人は ARM プロセッサの Mac を使っているのではありませんか。（Docker のバージョンによっては下に示したより多くの、たとえば "Run 'docker run --help' for more information" といったメッセージが出ているかもしれませんが、注目すべきは **"no matching manifest for linux/arm64/v8"** です。）

```bash
$ docker run -ti -v /tmp/P4runtime-protoswitch:/tmp p4lang/p4runtime-sh ....
....(snip)
docker: Error response from daemon: no matching manifest for linux/arm64/v8 in the manifest list entries: no match for platform in manifest: not found
$
```

Arm 版 Mac で P4C （や P4 Runtime Shell ）を動作させるためには、現時点では Rosetta を有効にする必要があります。Dockerhub の設定>>General>>Virtual Machine Options にある「Use Rosetta for x86_64/amd64 emulation on Apple Silicon」にチェックを入れてください。その上で docker コマンドに対して ```$ docker run --platform=linux/amd64 ...``` のように platform オプションを加えてやると良いでしょう。

#### 接続対象が自ホストの Docker コンテナでない場合

Tofino + Barefoot SDE など P4Runtime 対応の物理スイッチや、あるいは Mininet コンテナであったとしても別のマシンで動作している場合は、接続先の指定を host.docker.internal ではなく対象機の IP アドレスに合わせて下さい。```--grpc-addr 192.168.1.2:50001``` のようになるでしょう。

自ホストの Docker コンテナの場合は host.docker.internal が使えますので、このチュートリアルはそのように記述しておきます。

#### スイッチとの接続が切れた場合

実験をしている最中に、以下のようなメッセージが出ることがあります。これは P4Runtime Shell と接続している状態で Mininet を終了させたか、あるいは何らかの理由でネットワーク的な接続が切れた場合に起きます。

```bash
P4Runtime sh >>> CRITICAL:root:StreamChannel error, closing stream
CRITICAL:root:P4Runtime RPC error (UNAVAILABLE): Socket closed
```

このメッセージが表示された場合は、一度 P4Runtime Shell を終了して再度 Mininet に接続し直してください。そうしないと、スイッチに対する操作が効きません。

P4Runtime shell は exit コマンドで終了します。

```
P4Runtime sh >>> exit
$
```



さて、これでパケットを送受信することができる状態になりました。次に進みましょう。


## Next Step

#### Tutorial 1: [最も単純なスイッチ](t1_port2port.md)

