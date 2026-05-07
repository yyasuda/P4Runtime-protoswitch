## 雑多なこと

ここではチュートリアルを題材に、より深く学ぶための情報をまとめておきます。

* P4プログラムのコンパイル

___

### P4プログラムのコンパイル

独自の P4 スイッチプログラムを作りたい場合、P4 プログラムのコンパイルが必要です。

ここでの説明は /tmp/P4Runtime-protoswitch/test ディレクトリ以下にコンパイルしたい P4 プログラム、test.p4 がある状況を仮定しています。

```bash
$ ls /tmp/P4runtime-protoswitch/test
test.p4
$  
```

#### P4C コンテナの起動

以下のようにしてP4C Dockerコンテナを起動します。

```bash
$ docker run -it -v /tmp/P4Runtime-protoswitch/:/tmp/ p4lang/p4c /bin/bash
root@ab1f99459b1a:/p4c# cd /tmp/test
root@ab1f99459b1a:/tmp/test# ls
test.p4
root@ab1f99459b1a:/tmp/test# 
```

##### ARM Mac 版での注意

上の操作で **"no matching manifest for linux/arm64/v8 in the manifest list entries"** といったエラーが出た人は ARM プロセッサの Mac を使っているのではありませんか。

```bash
$ docker run -it -v /tmp/P4Runtime-protoswitch/:/tmp/ p4lang/p4c /bin/bash
Unable to find image 'p4lang/p4c:latest' locally
latest: Pulling from p4lang/p4c
docker: no matching manifest for linux/arm64/v8 in the manifest list entries
$
```

Arm 版 Mac で P4C （や P4 Runtime Shell ）を動作させるためには、現時点では Rosetta を有効にする必要があります。Dockerhub の設定>>General>>Virtual Machine Options にある「Use Rosetta for x86_64/amd64 emulation on Apple Silicon」にチェックを入れてください。その上で docker コマンドに対して ```$ docker run --platform=linux/amd64 ...``` のように platform オプションを加えてやると良いでしょう。

#### P4Cによるコンパイル

ホストの /tmp/P4Runtime-protoswitch ディレクトリと docker の /tmp を同期させていることに注意してください。

そこでp4cコンテナから見て /tmp/test 以下に見えているはずの test.p4 をコンパイルします。

```bash
root@ab1f99459b1a:/p4c# cd /tmp/test
root@ab1f99459b1a:/tmp/test# ls
test.p4
root@ab1f99459b1a:/tmp/test# p4c --target bmv2 --arch v1model --p4runtime-files p4info.txtpb test.p4 
root@ab1f99459b1a:/tmp/test# ls
p4info.txtpb  test.json  test.p4  test.p4i
root@ab1f99459b1a:/tmp/test# 
```

ここで生成した p4info.txtpb と test.json を使って、P4Runtime Shell を起動することになります。

各チュートリアルに用意されている p4info.txtpb や proto01.json ファイルなどはこのようにして作られたものです。

##### libboost_iostreams.so.1.71.0 が足りないとエラーになったら

もしコンパイルすると以下のようなエラーが出てしまった場合、あなたのコンテナイメージは 1.2.5.7 から 1.2.5.13 より小さい可能性が高いです。

```bash
root@897ac728fb57:/p4c# cd /tmp
root@897ac728fb57:/tmp# p4c --target bmv2 --arch v1model --p4runtime-files p4info.txtpb test.p4 
/usr/local/bin/p4c-bm2-ss: error while loading shared libraries: libboost_iostreams.so.1.71.0: cannot open shared object file: No such file or directory
root@897ac728fb57:/tmp#
```

どうやら少し前（おそらく Jun 4, 2025 の 1.2.5.7）に過剰にライブラリをパッケージから削ってしまったようで、libboost ライブラリが外れています。先ほど（April 19, 2026）に p4lang に Issue [\#5593](https://github.com/p4lang/p4c/issues/5593) を出したので近いうちに直るでしょうが、以下のようにして手作業で実行中のコンテナに libboost を追加インストールして対応することもできます。（7 May, 2026 に修正のための Pull Request [\#5612](https://github.com/p4lang/p4c/pull/5612) を出して受理され、 1.2.5.13 となって問題は解決しました。）

```bash
# apt update 
# apt install -y libboost-iostreams1.71.0
```



