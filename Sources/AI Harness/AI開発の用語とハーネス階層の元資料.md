# AI開発の用語とHarness階層

## このナレッジの位置づけ

AI開発では、AI、LLM、Model、Provider、Agent、Harnessといった言葉が同じ会話の中に現れる。
これらは近い場所で使われるため混同しやすいが、それぞれが指している対象は異なる。

このナレッジでは、Modelそのものの能力と、そのModelを実際の仕事へつなぐ仕組みを分けて整理する。
特にHarnessについては、役割の違いを理解しやすくするため、このプロジェクト内では人間に近い側を **Execution Harness**、Modelに近い側を **Agent Harness** と呼び分ける。

この二分類は、業界全体で統一された正式な分類として扱うものではない。
実際の製品では両方の役割が一体化している場合があり、まとめてHarnessと呼ばれることもある。

## AI、LLM、Model、Provider

**AI** は、人工知能に関する技術全体を指す広い概念である。
画像生成、音声認識、異常検知、ゲームAI、言語処理など、異なる種類の技術がこの範囲に含まれる。

その中で、文章やコードなどの言語を扱う大規模なモデルが **LLM（Large Language Model）** である。
したがって、AIとLLMは同義ではなく、LLMはAIの一種類として位置づけられる。

**Model** は、実際に選択して利用する個別の推論主体である。
同じProviderから複数のModelが提供されることがあり、性能、速度、得意分野、利用条件などが異なる。

**Provider** は、Modelを開発または提供する会社やサービスを指す。
ProviderとModelは包含関係ではなく、ProviderがModelを提供するという関係にある。

概念上の関係は、次のように整理できる。

```text
AI
└─ LLM
   └─ Model

Provider
└─ Modelを提供する
```

「OpenAIを使う」と「特定のGPT Modelを使う」は同じ意味ではない。
前者はProviderを指し、後者は実際に選択するModelを指している。

## ChatとAgent

通常のChatでは、人間が質問を渡し、Modelが回答を返した時点で一つの処理が終わる。
この形では、基本的に「質問に対して回答する」ことが中心になる。

一方の **Agent** は、目的を受け取ったあと、Modelの判断とToolの利用を繰り返しながら作業を進める。
ファイルを読む、コードを修正する、コマンドを実行する、結果を確認するといった操作を繰り返せるため、一度の回答で終了しない。

```text
Chat
人間 → 質問 → Model → 回答 → 終了

Agent
人間 → 目的
          ↓
       Modelが判断
          ↓
        Toolを使う
          ↓
        結果を確認
          └────→ 次の判断へ
```

Agentは「Modelより賢いもの」という意味ではない。
Modelの推論をToolの操作と接続し、結果を次の判断材料へ戻すことで、目的に向けた行動を継続できる仕組みとして捉える。

## Modelと推論強度

Modelの種類と、そのModelにどの程度の推論を行わせるかは別の軸である。
同じModelでも、製品やAPIが対応していればreasoning effortのような設定によって推論量を変更できる。

Modelは「どの頭脳を使うか」を決める。
推論強度は「その頭脳にどの程度考えさせるか」を決める。

強度を上げれば常に良いわけではない。
単純な文章修正や小さなコード変更では軽い設定で足りる場合があり、複雑な設計判断や原因分析では重い推論が役立つ場合がある。
その代わり、重い推論ほど時間や利用量が増える傾向があるため、タスクに合わせて選ぶ必要がある。

この区別を保つため、「GPT-5.6 Sol Max」のような表現を読むときも、Modelと強度を分けて考える。
このプロジェクト内の整理では、Modelは「GPT-5.6 Sol」、強度は「max」と扱う。

## Token、Context、Context Window、Cache

AIが扱う情報を理解するときは、Token、Context、Context Window、Cacheを分ける必要がある。
これらはすべて入力情報に関係するが、指しているものは異なる。

- **Token**：Modelが扱う情報量を数える単位。
- **Context**：その時点でModelが判断材料として参照している情報。
- **Context Window**：Modelが一度に扱えるContextの上限。
- **Cache**：以前に処理した入力の一部を再利用する仕組み。

Contextを「扱えるToken数の上限」と説明すると、Context Windowとの区別が崩れる。
Contextは実際に参照している情報であり、その保持可能量の上限がContext Windowである。

Cacheも長期記憶とは異なる。
共通の指示や繰り返し使う入力など、以前に処理した部分を再利用できる仕組みとして捉える。

```text
入力情報
  ↓
Tokenとして処理
  ↓
Contextとして参照
  ↓
Model
  ↓
出力

Context Window = Contextを一度に扱える上限
Cache          = 処理済み入力の一部を再利用
```

## Harnessという言葉が曖昧になる理由

Modelだけでは、現実の仕事は完結しない。
必要なContextを集め、Modelへ渡し、Toolを実行し、その結果を次の判断へ戻し、複数の作業を完了までつなぐ仕組みが必要になる。
この外側の仕組みが広くHarnessと呼ばれている。

ただし、Harnessという名前だけでは、どの範囲まで担当しているのかが分からない。
Modelのすぐ近くで一つのAgentを動かす仕組みも、人間から仕事を受けて複数の作業をまとめる仕組みも、同じHarnessという言葉で表現されることがあるためである。

そこで、このプロジェクトでは責務の違いを基準に二層へ分ける。

```text
人間
  ↓
Execution Harness
  ↓
Agent Harness
  ↓
Model
```

## Execution Harness

**Execution Harness** は、人間に近い側で仕事全体を受け取り、完了まで進行させる役割を持つ。
このプロジェクトでは、Pi、DSH、Hermesをこの側の例として扱う。

Execution Harnessが担うのは、単発のModel呼び出しではない。
人間から依頼を受け、必要な作業を整理し、Agent Harnessへ具体的な仕事を渡し、返ってきた結果を確認しながら次の作業へつなぐ。

典型的な流れは次のようになる。

```text
人間が仕事を依頼
  ↓
Execution Harnessが仕事を受け取る
  ↓
必要な作業を整理する
  ↓
Agent Harnessへ具体的な仕事を渡す
  ↓
結果を受け取る
  ↓
必要なら追加の仕事を渡す
  ↓
完了した結果を人間へ返す
```

したがって、Execution Harnessは単なるサンドボックスや実行インフラを指す言葉としては扱わない。
この分類で見ているのは、人間から受けた仕事全体を管理する責務である。

## Agent Harness

**Agent Harness** は、Modelに近い側で具体的な作業を進める役割を持つ。
このプロジェクトでは、Codex、Claude Code、GitHub Copilotをこの側の例として扱う。

Agent HarnessはExecution Harnessから仕事を受けると、ContextをModelへ渡し、Modelが決めた次の行動をToolへ接続する。
Toolの実行結果は再びContextへ入り、Modelは更新された情報を使って次の行動を決める。

```text
具体的な仕事を受け取る
  ↓
Context
  ↓
Modelが次の行動を判断
  ↓
Toolを実行
  ↓
結果を取得
  ↓
Contextを更新
  └────→ Modelが再判断
```

ファイル調査、コード修正、コマンド実行、テストといった実作業は、このループの中で継続される。
ModelそのものとAgent Harnessは同一ではなく、Agent HarnessがModelとToolを接続して一つのAgentとして作業を進める。

## Harnessの階層化

Execution Harnessは、一つのAgent Harnessだけを使う必要はない。
大きな仕事を複数の具体的な作業へ分け、それぞれを別のAgent Harnessへ任せる構成も取れる。

たとえば、「この機能を追加して」という依頼を、既存コードの調査、実装、テストへ分ける場合を考える。
Execution Harnessは全体の依頼を受け、三つの仕事を別々のAgent Harnessへ割り当て、返ってきた結果をまとめながら作業を進める。

```text
                  ┌→ Agent Harness A → Model
人間 → Execution ├→ Agent Harness B → Model
       Harness    └→ Agent Harness C → Model
```

この構造を使うと、「Harnessの上にHarnessがある」ように見える。
実際には同じ責務を重ねているのではなく、人間側の仕事全体を管理する層と、Model側で具体作業を実行する層が分かれている。

## なぜ両方ともHarnessと呼ばれるのか

実際の製品では、Execution HarnessとAgent Harnessに相当する責務が一つの製品内に含まれることがある。
利用者から見ると内部の境界が見えず、一つのHarnessとして扱っても不自然ではない。

一方、複数のAgentや複数の製品を組み合わせる設計では、この境界を分けて考えた方が責務を整理しやすい。
そのため、このプロジェクトでは一般的なHarnessという広い呼び方を残しつつ、説明上はExecution HarnessとAgent Harnessに分けている。

この呼び分けは「どちらか一方だけが本物のHarnessである」という主張ではない。
同じHarnessという言葉が異なる責務範囲に使われるため、その差を明示するための整理である。

## Modelの性能だけでは実用上の体験は決まらない

同じModelを使っていても、その外側のHarnessによって実際の作業の進み方は変わる。
Modelが高性能でも、人間が毎回Contextを渡し、次の操作を細かく指定し、Toolの結果を確認して再指示しなければならない構成では、人間側の作業が多く残る。

一方、Agent HarnessがModelとToolのループを回し、Execution Harnessが複数の作業を完了までつなげれば、人間が一つずつ操作を指示する必要は減る。
ここで変わっているのはModelの知能ではなく、Modelの能力を仕事へ接続する外側の構造である。

したがって、AI開発環境を比較するときはModel名だけを見ても足りない。
Model、推論強度、Agent Harness、Execution Harnessがどのように組み合わされているかを分けて見ると、実際の使い勝手の差を説明しやすくなる。

## 一文を分解する例

次の表現を、このナレッジの分類で分解する。

> 今回の改修はLLMでやってみようと思う。
> その際に使用するのはOpenAIのCodexで、GPT-5.6 Sol MaxをHermes上で使用してみよう。

この場合、それぞれの位置づけは次のようになる。

- **Provider**：OpenAI
- **Agent Harness**：Codex
- **Model**：GPT-5.6 Sol
- **推論強度**：max
- **Execution Harness**：Hermes

構造として並べると、次のようになる。

```text
人間
  ↓
Hermes
Execution Harness
  ↓
Codex
Agent Harness
  ↓
GPT-5.6 Sol
Model

reasoning effort = max
Provider = OpenAI
```

「GPT-5.6 Sol Max」を一つのModel名として扱わず、Modelと推論強度を分離して考える点が、この例の確認ポイントになる。

## 用語を使うときの注意

このナレッジのHarness分類は、製品名から機械的に決めるための一般規格ではない。
製品の機能範囲は変化し得るため、実際の製品を比較するときは、その時点でどの責務を担っているかを確認する必要がある。

また、Harnessの責務を説明するときは、セキュリティ機構、サンドボックス、権限管理、監視基盤などを同じ分類軸へ混ぜない。
それらを備える製品はあり得るが、この二層分類が分けているのは「人間から仕事全体を受ける側」と「Modelを使って具体作業を進める側」という責務である。

## 最終的な関係図

```text
AI
└─ LLM
   └─ Model

Provider ──提供──→ Model

人間
  ↓
Execution Harness
仕事全体を受け取り、完了まで回す
例：Pi / DSH / Hermes
  ↓
Agent Harness
ModelとToolを使い、具体的な作業を進める
例：Codex / Claude Code / GitHub Copilot
  ↓
Model
推論や生成を行う

Modelとは別軸：reasoning effort
Modelが参照する情報：Context
Contextの上限：Context Window
情報量の単位：Token
処理済み入力の再利用：Cache
```

この構造を基準にすると、「どのModelを使うか」と「そのModelをどう働かせるか」を別々に考えられる。
Modelの性能比較だけでは見えにくかったAI開発環境の違いを、責務の違いとして整理できる。
