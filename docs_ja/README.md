# P4Runtime-protoswitch
P4 初学者のための、極端なほど原始的な P4Runtime チュートリアルです。

## はじめに

このリポジトリにあるコードやデータは、P4Runtime を使った P4 Switch の制御を初めて試す人達に、簡単な入り口となるチュートリアルとして作成されました。P4および P4Runtime については、ある程度の理解があることを仮定しています。実際に手元で試すのが初めて、という人にとって良い入り口となりますように。

## This tutorial does…

このチュートリアルでは、以下の三つのことを試します。

- 入力ポート情報だけを用いたパケットの転送
- 宛先MACアドレスに応じたパケットの転送
- マッチ・テーブルを用いたパケットの転送

これらの実験は、以下の環境で行います。

- コントローラ役には P4Runtime Shell を用いる
- スイッチ役には P4Runtime に対応した Mininet を用いる
- P4 コンパイルにはオープンソースの p4c を用いる

これら全て Docker 環境で動作するもので揃えています。最初はこのドキュメントに記述にあるものをそのまま使って下さい。

## Tools

このチュートリアルではすべて Docker 環境で実験を行います。

#### P4C

- Docker Hub: [p4lang/p4c](https://hub.docker.com/r/p4lang/p4c) 

#### P4Runtime-enabled Mininet Docker Image (modified)

- Docker Hub: [yutakayasuda/p4mn](https://hub.docker.com/r/yutakayasuda/p4mn) 
- GitHub: [yyasuda/p4mn-docker](https://github.com/yyasuda/p4mn-docker)

オリジナルの [opennetworking/p4mn](https://hub.docker.com/r/opennetworking/p4mn) でもほとんど同じように動作しますが、ログなどの扱いがあまりうまくできないので自分で作りました。

#### P4Runtime Shell

- Docker Hub:  [P4Runtime Shell](https://hub.docker.com/r/p4lang/p4runtime-sh)

## Step by Step

以下に一つずつ手順を示します。順番に試していくのが良いでしょう。

### Tutorial 0: [実験環境の準備](t0_prepare.md)

実験に先だって、P4 スイッチプログラムのコンパイルが必要です。次にMininetを起動し、そこにコントローラ代わりとなる、P4 Runtime Shell を接続させます。

### Tutorial 1: [最も単純なスイッチ](t1_port2port.md)

port 1 から入ってきたパケットは port 2 へ、port 2 から入ってきたパケットは port 1 へ転送するだけの、極端に単純なスイッチプログラム、port2port.p4 を用いた転送実験を行います。

### Tutorial 2: [ヘッダのパース（解釈）](t2_macaddr.md)

ここではヘッダのパース（解釈）を行い、取り出した宛先MACアドレスフィールドの情報によって転送先を決定するスイッチプログラム、macaddr.p4 を試します。

### Tutorial 3: [テーブルへのエントリ追加](t3_add_entry.md)

P4 には Match Action Table と呼ばれるものがあり、これを使ってパケットごとに必要な処理（アクション）を適用することができます。ここでは宛先 MACアドレスをキーとして持つ表によって転送先を決定するスイッチプログラム、tablematch.p4 を試します。

## Next Step

このチュートリアルでは内部構造に触れることなく、分かりやすい入り口を示すことに集中しました。次はそこを入り口に、中を掘っていくことになるかと思います。これまでに私が読んで、特に有益だったドキュメントについて、幾つか挙げておきます。

- [P4Runtime Specification](https://p4.org/specifications/) v1.5.0 [[HTML](https://p4lang.github.io/p4runtime/spec/v1.5.0/P4Runtime-Spec.html)] [[PDF](https://p4lang.github.io/p4runtime/spec/v1.5.0/P4Runtime-Spec.pdf)]
- P4Runtime proto p4/v1/[p4runtime.proto](https://github.com/p4lang/p4runtime/blob/master/proto/p4/v1/p4runtime.proto) 
- P4Runtime proto p4/config/v1/[p4info.proto](https://github.com/p4lang/p4runtime/blob/master/proto/p4/config/v1/p4info.proto) 
- [P4<sub>16</sub> Portable Switch Architecture (PSA)](https://p4.org/specifications/) v1.2 [[HTML](https://p4.org/wp-content/uploads/sites/53/p4-spec/docs/PSA-v1.2.html)] [[PDF](https://p4.org/wp-content/uploads/sites/53/p4-spec/docs/PSA-v1.2.pdf)]
  上記P4Runtime Specification では、1.2 In Scope をはじめ、P4RuntimeはPSAをある程度仮定している記述が散見されます。今回のチュートリアルには特に関係ありませんでしたが、気になる記述があれば読むと良いかと。




