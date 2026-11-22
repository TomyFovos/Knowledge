# AWS Nitro Sandboxes キャッチアップのナレッジ

## 概要

AWS Nitro Sandboxes は、1台のEC2インスタンスの中に軽量な仮想マシンを作り、EKSのポッド、ECSのタスク、AIエージェントなどを1つずつ専用の仮想マシンに入れて動かす仕組みである。AWSが2026年11月9日に発表した。

- 1台のインスタンスを共有したまま、ワークロードごとに仮想マシンの強さで隔てられる
- 仕切りは、AWSのハードウェアに組み込まれた Nitro の仕組みが受け持つ
- EKSやECSでは、設定を1行変えるだけで使える
- 改ざんされていないことを暗号で証明できた環境にだけ、秘密情報を渡せる
- 主な用途として、AIが生成したコードを安全に実行することが挙げられている

## 理解に必要な前提

### サンドボックス

プログラムを閉じ込め、外に影響を出させないようにする仕組みをまとめて指す言葉である。壁の作り方と強さはさまざまで、同じ「サンドボックス」でも中身は大きく違う。

### 壁の厚さの段階

壁が薄いものから順に並べると、次のようになる。

```
薄い
 │ OSの機能でコマンドを制限する
 │ ふつうのコンテナ（OSの中心部分を共有）
 │ OSの代役を挟む方式（gVisor など）
 │ 軽量な仮想マシン ← Nitro Sandboxes
 │ 別々のサーバー
厚い
```

ふつうのコンテナはOSの中心部分（カーネル）をホストと共有する。軽くて速い反面、1つのコンテナが乗っ取られると、隣のコンテナにまで手が届くおそれがある。軽量な仮想マシンはワークロードごとに専用のOSの中心部分を持たせるので、サーバーを分けたときに近い強さで隔てられる。

### EKSのポッドとECSのタスク

どちらもAWSでコンテナを動かすときの実行単位である。EKSはKubernetes、ECSはAWS独自の仕組みでコンテナを管理する。

### 暗号による証明

環境の中身が改ざんされていないことを、暗号の仕組みで示すことである。証明できた環境にだけパスワードや鍵を渡す、という運用に使う。

## 解説

### 何が新しいか

これまで、信用できないコードを動かすなら、サーバーごと分けるのが安全だった。Nitro Sandboxes では、1台のインスタンスを共有したまま、ポッドやタスクを1つずつ別の仮想マシンとして隔てられる。性能はEC2をそのまま使うときとほぼ変わらないとされている。

```
ふつうのコンテナ
EC2 ─ OSの中心部分（共有）
       ├ コンテナA
       └ コンテナB  ← Aが破られると届きうる

Nitro Sandboxes
EC2 ─ Nitro の仕切り
       ├ 仮想マシン ─ ポッドA
       └ 仮想マシン ─ ポッドB  ← 別々に隔離
```

### 使い方

EKSやECSでは、設定を1行変えると、ポッドやタスクごとに専用の仮想マシンが用意される。中のアプリは Pod Identity、VPC CNI、EBS・EFS・S3、CloudWatch をこれまでどおり使えると発表されている。

細かく制御したいときは、EC2の上で直接動かせる。自分のAMIやオーケストレーション、仮想マシンを動かすソフト（VMM）を組み合わせる。Amazon Linux と Firecracker に対応している。

### 使われる場面

AIエージェントが書いたコードを実行するサービスが代表例である。生成されたコードが何をするかは、事前には分からない。利用者ごと、実行ごとに専用の仮想マシンで動かせば、1つのコードが暴走しても、ほかの利用者のデータやサーバー本体には届きにくくなる。1台のインスタンスにまとめて載せられるので、利用者ごとにサーバーを立てるより費用を抑えられる。

### 提供範囲と料金

発表の時点では、ほとんどのNitroベースのEC2インスタンスで、すべての商用リージョンで使える。追加料金はかからない。

## 似たものとの違い

| 名前 | 動く場所 | 壁の作り方 | 壁の厚さ | 主な使い手 |
|---|---|---|---|---|
| Codex のサンドボックス | 手元のPC | OSの機能でコマンドを制限。書き込める場所を作業フォルダなどに限る | 薄め | 開発者 |
| Claude Code のサンドボックス | 手元のPC | OSの機能で、シェルのコマンドのファイルとネットワークを制限。ファイル編集の機能とMCPサーバーは対象外 | 薄め | 開発者 |
| Docker Sandboxes | 手元のPC | エージェントごとに軽量な仮想マシン。手元と共有するのはプロジェクトのフォルダだけ | 厚め | 開発者 |
| ふつうのコンテナ | サーバー | OSの中心部分を共有 | 薄め | サービスを作る側 |
| gVisor など | サーバー | アプリとOSの間にOSの代役を挟む | 中くらい | サービスを作る側 |
| E2B など | 外部のサービス | 軽量な仮想マシンをサービスとして貸し出す | 厚め | サービスを作る側 |
| Nitro Sandboxes | 自分のEC2 | Nitro の仕組みで、1つずつ軽量な仮想マシンに入れる | 厚め | AWSでサービスを作る側 |

Codex、Claude Code、Docker Sandboxes の記述は、各社の資料と解説記事で確かめた。gVisor と E2B の記述は会話の中での整理で、今回は一次資料を確かめていない。

位置づけは「壁の厚さ」と「どこで誰のために使うか」の2つで整理できる。

```
手元のPCで、自分のエージェントを守る
 ├ Codex / Claude Code（薄め）
 └ Docker Sandboxes（厚め）

サーバーで、大勢のコードを動かす
 ├ ふつうのコンテナ（薄め）
 ├ gVisor など（中くらい）
 └ 1つずつ仮想マシン（厚め）
     ├ E2B など：サービスとして借りる
     └ Nitro Sandboxes：自分のEC2で動かす
```

## 会話でわかったこと

### 「ふつうのサンドボックス」との関係

Nitro Sandboxes もサンドボックスの一種である。違いは壁の厚さで、ワークロードを1つずつ仮想マシンとして分け、その仕切りをAWSのハードウェア側が受け持つ。仮想マシンで分ける方法は前からあったが、起動や管理の手間が大きく、コンテナのように気軽には使えなかった。コンテナと同じ感覚のまま仮想マシン並みの壁で囲める点が新しい。

### クラウドの厚めのサンドボックスとして新しいのか

厚めのサンドボックス自体は E2B のような貸し出しサービスとして以前からあった。新しいのは、厚めのサンドボックスを自分のEC2、EKS、ECSの中で、標準の機能として手軽に使えるようになった点である。これまで自分のAWS環境で同じことをするには、外部のサービスに任せるか、仮想マシンを動かす仕組みを自分で組む必要があった。

### Docker Sandboxes の代わりになるか

代わりにはならない。Docker Sandboxes は、開発者が自分のPCで Claude Code などのエージェントを動かすときの道具である。Nitro Sandboxes はEC2の上で動くので、自分のPCでエージェントを使う場面は変わらない。

Nitro Sandboxes で楽になるのは、AWSの上でエージェントや他人のコードを動かすサービスを作る側である。たとえば「AIにコードを書かせて、その場で実行する」仕組みをEKSやECSで作る場合、設定を1行変えるだけで、実行ごとに厚い壁で隔てられる。

## 未解決事項

- 「設定を1行」の具体的な設定項目（EKSとECSのユーザーガイドは未読）
- 対象のインスタンスの種類の詳細（発表では「ほとんどのNitroベースのインスタンス」）
- 仮想マシンの起動にかかる時間と、1台のインスタンスに載せられる数の目安
- 暗号による証明の具体的な使い方
- これまでEC2の上で Firecracker などを動かすときの条件と、何が変わったか

## 参考資料

いずれも2026年11月10日に確かめた。

- AWS What's New「Introducing AWS Nitro Sandboxes on Amazon EKS, ECS and EC2 for hardware isolated pods, tasks and VMs」（2026年11月9日掲載） https://aws.amazon.com/jp/about-aws/whats-new/2026/11/nitro-sandboxes-eks-ecs-ec2/
- Amazon EKS ユーザーガイド（未読） https://docs.aws.amazon.com/eks/latest/userguide/sandboxing.html
- Amazon ECS デベロッパーガイド（未読） https://docs.aws.amazon.com/AmazonECS/latest/developerguide/isolated-confidential-tasks.html
- Amazon EC2 ユーザーガイドの Nitro Sandboxes（未読） https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/amazon-ec2-nitro-sandboxes.html
- Claude Code のドキュメント「Sandboxing」 https://code.claude.com/docs/en/sandboxing
- Claude Code のドキュメント「Sandbox environments」 https://code.claude.com/docs/en/sandbox-environments
- Codex のサンドボックスの解説記事 https://codex.danielvaughan.com/2026/04/08/codex-sandbox-platform-implementation/
- Docker のドキュメント「Docker Sandboxes」 https://docs.docker.com/ai/sandboxes.md
- Docker のブログ「Docker Sandboxes: Run Claude Code and Other Coding Agents Unsupervised (but Safely)」 https://www.docker.com/blog/docker-sandboxes-run-claude-code-and-other-coding-agents-unsupervised-but-safely/

## 更新履歴

- 2026-11-10：初版
