# Docker Sandboxes 学習・ブログ統合ナレッジ

更新日：2026-10-01

## このナレッジの目的

この文書は、Docker Sandboxesについて学習した内容と、技術ブログ「【サンドボックス】開発速度と権限設定の両立」を作成する過程で固まった考え方を、後から再利用できる形でまとめたものです。
対象読者はIT初学者を想定しており、Dockerや仮想化を知っていることを前提にしません。
文章だけで内部構造を説明し切ろうとせず、構造、比較、経路、役割分担は画像へ移し、本文では「なぜその仕組みが必要なのか」と「何に注意するのか」を理解できる構成にします。

この文書では、学習上の理解とブログ制作上の決定を分けて記録します。

---

# 1. 今回の出発点

AIエージェントへ開発を任せる範囲が広がるほど、Permission確認が開発速度の制約になります。
一体のAIエージェントを人間が横で見ながら使う場合は、ファイル編集やコマンド実行のたびに承認しても大きな問題にはなりません。
しかし、複数のAIエージェントへ仕事を分けて並列で動かす場合、それぞれが数分おきに承認を求めると、人間がボトルネックになります。

そこでFull Accessを使いたくなりますが、会社PCそのものへ強い権限を与えると、開発対象以外のファイル、設定、認証情報、別プロジェクトなどにも影響が届く可能性があります。
今回の中心となる考え方は、次の一文に集約できます。

> AIエージェントを毎回止めるのではなく、止めなくてもよい範囲を先に作る。

会社PC全体へのFull Accessではなく、壊れても作り直せる隔離環境の中だけへFull Accessを与えることで、開発速度と安全性の両立を目指します。

---

# 2. Sandboxとは何か

**Sandbox**は、あるプログラムが自由に動いてよい範囲を先に区切り、その外側へ影響が広がりにくくするための考え方です。
AIエージェントの場合は、会社PCの中に「AIが自由に使ってよい別の作業場所」を作ると考えると理解しやすくなります。
AIはその中でファイルを編集し、開発ツールを追加し、テスト環境を構築し、必要な処理を実行できます。

ここで大切なのは、Full Accessという設定そのものを危険視するのではなく、その権限がどこまで届くかを見ることです。
会社PCそのものへFull Accessを与えた場合と、Sandbox内部だけへFull Accessを与えた場合では、同じ「Full Access」でも影響範囲が異なります。

---

# 3. Container、VM、microVMの理解

通常のContainerは、Host側のOS Kernelを共有しながら、プロセスやファイルシステムを分離します。
一方、VMは仮想的なコンピューターを一台作り、その中に独立したOS Kernelを持ちます。
Docker Sandboxesで使われる**microVM**は、このVMに近い隔離を、AIエージェント用途で扱いやすい形にしたものとして理解します。

Docker SandboxesをIT初学者へ説明するときは、内部技術を先に出すよりも「会社PCの中にAI専用の小さな別PCを作る」と説明するほうが理解しやすくなります。
Dockerを知っている読者向けには、通常のDocker ContainerへAIを入れているだけではなく、Sandboxごとに独立したmicroVMを使っていることを補足します。

---

# 4. Docker Sandboxesで得たい状態

Docker Sandboxesを利用する目的は、AIエージェントを弱くすることではありません。
むしろ、Sandbox内部ではファイル編集、開発ツールの追加、テスト環境の構築、Dockerの利用などを広く許可し、その自由が会社PC全体へ広がらないようにします。

考え方は次のようになります。

```text
会社PC
  ├─ 社内ファイル
  ├─ 別プロジェクト
  ├─ 認証情報
  └─ 開発者の設定

        境界

  Docker Sandbox
  ├─ AI Agent
  ├─ 開発対象
  ├─ 開発ツール
  ├─ テスト環境
  └─ Sandbox専用の実行環境
```

AIがSandbox内部の環境を壊しても、その環境を削除して作り直せるのであれば、人間が一つずつ操作を承認する必要を減らせます。

---

# 5. Sandboxがあれば絶対に安全なのか

Sandboxは、導入しただけで安全を保証する仕組みではありません。
AIエージェントが実際に開発するためには、ソースコード、外部ネットワーク、認証情報、MCPなど、Sandboxの外側とつながる経路が必要になります。

したがって、安全性を見るときは「Sandboxが存在するか」だけではなく、「Sandboxの外へ何を接続しているか」を確認します。
今回整理した主な出入口は、次の4つです。

- **ソースコード**：会社PC側の開発対象をどのようにAIへ渡すか。
- **ネットワーク**：どの外部サービスへ接続できるか。
- **認証情報**：APIキーやパスワードをAIへどのように使わせるか。
- **MCP**：Sandbox外のツールやシステムへどこまで操作を許すか。

Sandboxの境界そのものより、これらの出入口の設定が実際の安全性を左右する場合があります。

---

# 6. Direct modeとClone mode

ソースコードをAIへ渡す方法として、理解しておきたいのがDirect modeとClone modeです。

## Direct mode

Direct modeでは、会社PC側の開発フォルダをSandboxから直接操作します。
AIの変更が会社PC側へすぐ反映されるため、対話的な開発には便利です。
一方、AIが誤ってファイルを削除した場合も、その変更が会社PC側へ届きます。

## Clone mode

Clone modeでは、Sandbox内部へ作業用のコピーを作り、AIはそのコピーを編集します。
会社PC側の元ファイルをその場で書き換えないため、AIの変更を確認してから取り込めます。
複数AIの並列開発や、AIの変更を人間がレビューしてから統合したい場合に扱いやすい方式です。

ただし、Clone modeは「元ファイルを書き換えられない」ための仕組みであり、「元ファイルを読めない」ための仕組みではありません。
Git管理外のファイルや`.gitignore`対象のファイルであっても、会社PC側のRepository配下に置かれていれば、AIから読める可能性があります。
そのため、秘密情報の扱いはClone modeとは別に設計します。

---

# 7. Credential Proxy

APIキーやパスワードをSandboxへそのまま渡すと、AIやSandbox内で動くプログラムから、その値自体を読むことができます。
Docker Sandboxesでは、**Credential Proxy**を使い、秘密の値そのものをAIへ直接渡さず、外部サービスへアクセスするときだけ代理で認証情報を付与する考え方を取れます。

イメージは次のとおりです。

```text
AI Agent
   │
   │ 「GitHubでこの操作をしたい」
   ▼
Credential Proxy
   │
   │ 保存している認証情報を利用
   ▼
外部サービス
```

AIから見ると「サービスは使えるが、APIキーやパスワードそのものは知らない」という状態になります。
ただし、Credential Proxyを使っても、そのCredentialが持つ権限まで消えるわけではありません。

たとえばGitHubへのpush権限を持つCredentialを使わせれば、AIはTokenそのものを知らなくてもpushできます。
「秘密を見せないこと」と「その権限で何をしてよいか」は別の問題として扱います。

---

# 8. Network制御

Sandboxからインターネットへ自由に接続できれば、GitHubや外部AIサービスを利用しやすくなる一方、Sandbox内部の情報を外へ送るための経路にもなります。
そのため、開発に必要なサービスだけへ接続できるようにNetworkを制御する考え方が必要です。

たとえば、次のような構成を考えます。

```text
許可
  ├─ GitHub
  ├─ 利用中のAIサービス
  ├─ 必要なPackage Registry
  └─ 必要なAPI

遮断
  ├─ 不要なWebサイト
  ├─ 個人用クラウド
  ├─ 不要な社内システム
  └─ その他の未許可接続
```

AIにSandbox内部の強いファイル権限を与えることと、インターネットを無制限に使わせることは同じではありません。
Sandbox内では自由に開発させながら、外部との通信先だけを狭くできます。

---

# 9. MCPは別の出口になる

MCPを使うと、AIエージェントから外部のツールやシステムを操作できるようになります。
便利な一方で、MCPはSandboxの外へ能力を追加するための別の出口になります。

たとえば会社PC上で動くMCP ServerにHost filesystemを操作する機能があれば、Sandbox内のAIがそのMCPを呼び出すことで、Sandbox外のファイルへ操作が届く場合があります。
このとき、AIがSandboxを破ったわけではありません。
人間が用意したMCPという正規の通路を使って外側へ操作しています。

したがって、Network Policyだけを見ても不十分であり、MCPについても「どのServerを使えるか」「どのToolを呼べるか」「どこまで操作できるか」を別に確認します。

---

# 10. 複数AIエージェントの並列開発

Docker Sandboxesは、AIエージェント同士の環境を分離する用途にも使えます。
たとえばAgent A、B、Cを別々のSandboxへ配置すれば、それぞれが独立した開発環境を持てます。

```text
Windows会社PC
   │
   ├─ Sandbox A
   │    └─ Agent A
   │
   ├─ Sandbox B
   │    └─ Agent B
   │
   └─ Sandbox C
        └─ Agent C
```

Agent Aが開発ツールや設定を変更しても、その変更がAgent BやCの環境へそのまま広がりません。
一方、すべてのAIを必ず別Sandboxへ分ける必要があるわけではありません。

同じ環境を共有しながら協力させたいAgentは同じSandboxへ置き、互いの環境に影響してほしくないAgentは別Sandboxへ分けます。
判断基準はAIの数ではなく、**何を分離したいか**です。

---

# 11. OrchestratorとWorkerをどう考えるか

学習中には、統括Agent AがWorker B、C、Dを管理し、それぞれをさらに別microVMへ入れる構成を検討しました。
狙いは正しく、統括Agentだけが全体を把握し、Worker同士を独立させる設計です。
ただし、Docker Sandboxesの標準的な使い方として、Sandbox内部へさらにDocker SandboxのmicroVMをネストする形を前提にする必要はありません。

独立性を重視する場合は、Host側に複数Sandboxを並べ、OrchestratorにはWorker作成、指示、状態確認、成果回収など、必要な操作だけを許す専用の制御口を用意する構成のほうが安全です。

```text
Orchestrator
     │
     │ 限定された制御
     ▼
Orchestration Interface
   ├─ Sandbox B
   ├─ Sandbox C
   └─ Sandbox D
```

この部分は、Docker Sandboxes単体の知識から一歩進み、AI Agent HarnessやExecution Harnessの設計領域になります。

---

# 12. A/Bテストへの利用

Sandboxを複数作れることは、AIエージェントのA/Bテストにも使えます。
AI Agent AとBを比較したい場合、Agent以外の条件を揃えなければ、結果の差がAIによるものか環境によるものか分かりません。

たとえば、次の条件を揃えます。

- CPU
- メモリ
- 元になるGit commit
- 開発ツール
- Network条件
- テスト方法
- 評価条件

そのうえで、比較したいものだけを変えます。

```text
同じ条件
   │
   ├─ Sandbox A → Agent A
   │
   └─ Sandbox B → Agent B
```

Agentを比較するならAgentだけを変えます。
Promptを比較するならPromptだけを変えます。
Harnessを比較するならHarnessだけを変えます。

Sandboxは安全のための隔離環境であるだけでなく、**同じ実験環境を複製するための単位**としても利用できます。

---

# 13. 会社PCで想定する構成

今回想定している利用環境は、Windows会社PC上で複数のAIエージェントを並列稼働させ、AIへ強いPermissionを与えながらHostへの影響を抑える構成です。
概念構成は次のようになります。

```text
Windows会社PC
│
├─ Main Repository
├─ Credential管理
├─ Network Policy
├─ MCP Policy
│
├─ Sandbox A
│   ├─ Agent A
│   ├─ Private Clone
│   └─ 独立した開発環境
│
├─ Sandbox B
│   ├─ Agent B
│   ├─ Private Clone
│   └─ 独立した開発環境
│
└─ Sandbox C
    ├─ Agent C
    ├─ Private Clone
    └─ 独立した開発環境
```

基本方針は、AIに強い権限を与える代わりに、その権限が届く範囲をSandbox内部へ閉じ込めることです。
Host側への接続は、ソースコード、Network、Credential、MCPなど、必要な経路だけを明示的に開けます。

---

# 14. 今回の理解度テストで修正した点

学習中の回答から、次の3点を明確に分ける必要があると分かりました。

## Workspace isolation

Workspace isolationは、Hostのコードへ「書けるか」「読めるか」を扱います。
Clone modeではHost側の元ファイルを書き換えにくくできますが、元Repositoryを読めなくする仕組みではありません。

## Credential isolation

Credential isolationは、APIキーやパスワードの実値をAIへ直接見せないための仕組みです。
Credential Proxyを使っても、そのCredentialに許可された操作そのものが禁止されるわけではありません。

## MCP isolation

MCPはNetworkとは別の外部接続経路です。
Networkを制限しているからMCPも安全になるわけではなく、MCP ServerとToolの権限を別に管理する必要があります。

---

# 15. ブログ記事の方針

記事タイトルは次の方向で作成しました。

> 【サンドボックス】開発速度と権限設定の両立

読者はIT初学者を想定します。
Dockerを知っていることを前提にせず、Docker Container、Kernel、Hypervisor、Docker daemonなどの内部構造を本文で詳しく説明しすぎないようにします。

本文では、「なぜSandboxが必要なのか」「何を隔離するのか」「Sandboxを使っても残る出入口は何か」を説明します。
構造や比較は画像へ移し、本文と画像が完全に同じ説明を繰り返さないようにします。

記事の中心メッセージは次のとおりです。

> AIを毎回止めるのではなく、止めなくてもよい範囲をあらかじめ作る。

---

# 16. ブログ記事の構成

記事は次の流れで作成します。

1. AIエージェントのPermission確認が並列開発のボトルネックになる。
2. Full Accessを使いたくなるが、会社PC全体へ与えるのは危険である。
3. Sandboxという考え方を導入する。
4. Docker Sandboxesを「AI用の別PC」として説明する。
5. SandboxによってPermission確認を減らせる理由を説明する。
6. Sandboxは完全密閉ではなく、外部との出入口を持つことを説明する。
7. ソースコード共有としてDirect modeとClone modeを説明する。
8. Credential Proxyを説明する。
9. Network制御を説明する。
10. MCPが別の出口になることを説明する。
11. 複数Agentの並列開発へつなげる。
12. A/Bテストへ応用する。
13. Sandboxがあれば絶対安全という理解を否定する。
14. 開発速度と安全性を両立する考え方で締める。

---

# 17. 記事用画像の対応表

今回の記事では、文章より図で理解しやすい内容を画像へ移しました。

## 01：隔離環境から外部へつながる経路

記事冒頭の事故紹介に対応します。
Sandbox内のAIが、許可されたサービスや設定上の隙間を経由して外部へ到達する概念を示します。
伝えたいことは、「箱だけを見るのではなく、外につながる経路全体を見る必要がある」です。

## 02：Full Accessの範囲比較

会社PCそのものへFull Accessを与えた場合と、Sandbox内部だけへFull Accessを与えた場合を比較します。
同じFull Accessでも、届く範囲が違うことを視覚化します。

## 03：Docker SandboxesはAI用の別PC

Windows会社PCの中にDocker Sandboxという独立した作業環境があり、その中でAIが自由に開発する構造を示します。
IT初学者には「microVM」という言葉より、「AI用の別PC」というイメージを先に伝えます。

## 04：権限確認ありとSandbox内Full Access

通常環境ではAIと人間の間で確認が何度も発生し、Sandbox内Full AccessではAIが連続して作業できることを比較します。
記事タイトルである「開発速度と権限設定の両立」を直接表す画像です。

## 05：Sandboxの4つの出入口

中央にSandboxを置き、その周囲へ「ソースコード」「ネットワーク」「認証情報」「MCP」の4つを配置します。
Sandboxは完全密閉ではなく、開発のために必要な出入口を持つことを示します。

## 06：Direct modeとClone mode

Direct modeでは会社PC側の開発フォルダを直接編集し、Clone modeではSandbox内の作業用コピーを編集する違いを示します。
複数AI開発やレビュー前提ではClone modeが扱いやすいことを視覚化します。

## 07：Credential Proxy

APIキーやパスワードをAIへ直接渡す場合と、Credential Proxyを仲介させる場合を比較します。
AIは外部サービスを利用できても、秘密情報そのものを知る必要はないことを示します。

## 08：Network制御

Sandboxから接続できる外部サービスを制限する考え方を示します。
GitHubや必要なAIサービスは許可し、不要なWebサイトや未許可サービスは遮断する構図です。

## 09：MCPは別の出口

Sandbox内のAIからMCPを経由し、Hostや外部サービスへ操作が届く流れを示します。
「Sandboxに入っているからMCPも自動的にSandbox内へ閉じる」という誤解を避けるための画像です。

## 10：複数AIの並列開発

Sandbox A、B、Cを独立させ、それぞれにAgent A、B、Cを配置します。
各Agentが別環境で同時に開発でき、互いの環境変更を受けにくいことを示します。

## 11：A/Bテスト

Sandbox AとBへ同じ環境、同じデータ、同じタスク、同じ設定を用意し、AI Agentだけを変更します。
比較対象以外の条件を揃えることで、Agentごとの得意不得意を比較できることを示します。

---

# 18. 画像制作で発生した修正

画像1〜6は記事内容に対応したものとして採用しました。
画像7以降では、一度別の記事であるAzure SRE Agentの画像内容が混入したため、すべて作り直しました。

最終的な画像7〜11の対応は次のとおりです。

```text
07 Credential Proxy
08 Network制御
09 MCP
10 複数AIの並列開発
11 A/Bテスト
```

今後画像を再生成する場合は、この対応表をSSOTとして扱います。

---

# 19. 参考情報

今回の学習と記事作成では、OpenAI、Anthropic、Dockerの公開情報を確認しました。

- OpenAI：Hugging Face incident and the road ahead  
  https://openai.com/index/hugging-face-incident-and-the-road-ahead/
- Docker Sandboxes documentation  
  https://docs.docker.com/ai/sandboxes/
- Docker Sandboxes security  
  https://docs.docker.com/ai/sandboxes/security/
- Docker Sandboxes isolation  
  https://docs.docker.com/ai/sandboxes/security/isolation/
- Docker Sandboxes credentials  
  https://docs.docker.com/ai/sandboxes/configuration/credentials/
- Docker Sandboxes MCP Gateway  
  https://docs.docker.com/ai/sandboxes/mcp-gateway/

公開仕様は更新されるため、実際に会社PCへ導入するときは、その時点のDocker公式ドキュメントで要件と挙動を再確認します。

---

# 20. 再開時の前提

この学習を別セッションで再開する場合は、次の前提を共有すると話を続けやすくなります。

- 目的は、Windows会社PC上でAIエージェントへ強いPermissionを与えながら、Hostへの影響を制限すること。
- 複数Agentの平行・並列開発を想定する。
- A/Bテスト用に同条件の環境を複製したい。
- Docker Sandboxesは「AI用の別PC」として理解している。
- Full Accessそのものより、権限が届く範囲を問題として捉える。
- Sandboxの主な出入口は、ソースコード、Network、Credential、MCP。
- 並列開発では、独立性が必要なAgentは別Sandboxへ分ける。
- A/Bテストでは、比較対象以外の環境条件を揃える。
- Sandboxが存在するだけでは安全を保証できず、境界を越える経路まで確認する。
- ブログ記事はIT初学者向けで、内部構造は画像へ移し、本文は段落で自然に説明する。
- 記事用画像は01〜11まであり、07〜11は修正版を採用する。
