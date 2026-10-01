# AI開発の用語とハーネスの階層

AI開発の会話には、AI、LLM、Model、Provider、Agent、Harnessといった言葉が一緒に出てくる。
近い場所で使われるので混同しやすいが、それぞれが指す対象は違う。
特にHarnessは、Modelのすぐ近くで一つのAgentを動かす仕組みにも、人間から仕事を受けて複数の作業をまとめる仕組みにも使われるため、名前だけでは担当範囲が分からない。

このノートでは、Modelそのものの能力と、そのModelを実際の仕事へつなぐ仕組みを分けて整理する。
Harnessについては、元メモのプロジェクト内の呼び分けとして、人間に近い側を **Execution Harness**、Modelに近い側を **Agent Harness** と呼ぶ。

この二分類は、業界全体で統一された正式な分類ではない。
実際の製品では両方の役割が一体化していることがあり、まとめてHarnessと呼ばれることもある。

## AI、LLM、Model、Providerは別の対象を指す

- **AI（人工知能）**：人工知能に関する技術全体を指す広い概念。画像生成、音声認識、異常検知、ゲームAI、言語処理など、種類の違う技術が含まれる。
- **LLM（Large Language Model、大規模言語モデル）**：文章やコードなどの言語を扱う大規模なモデル。AIの一種類であり、AIと同義ではない。
- **Model（モデル）**：実際に選んで使う個別の推論主体。同じProviderから複数のModelが提供され、性能、速度、得意分野、利用条件が異なる。
- **Provider（提供元）**：Modelを開発または提供する会社やサービス。

ProviderとModelは包含関係ではない。
ProviderがModelを提供する、という関係である。

```text
AI
└─ LLM
   └─ Model

Provider
└─ Modelを提供する
```

「OpenAIを使う」と「特定のGPT Modelを使う」は同じ意味ではない。
前者はProviderを指し、後者は実際に選ぶModelを指している。

## Agentは回答で終わらず、判断とTool利用を繰り返す

通常の **Chat（チャット）** では、人間が質問を渡し、Modelが回答を返した時点で一つの処理が終わる。
中心は「質問に対して回答する」ことである。

**Agent（エージェント）** は、目的を受け取ったあと、Modelの判断と **Tool（道具。ファイル操作やコマンド実行などModelの外で動く機能）** の利用を繰り返しながら作業を進める。
ファイルを読む、コードを修正する、コマンドを実行する、結果を確認する、といった操作を繰り返せるので、一度の回答では終わらない。

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
Modelの推論をToolの操作とつなぎ、結果を次の判断材料へ戻すことで、目的に向けた行動を続けられる仕組みである。

## Modelと推論強度は別の軸である

どのModelを使うかと、そのModelにどの程度推論させるかは別の軸である。
同じModelでも、製品やAPIが対応していれば、**推論強度（reasoning effort）** のような設定で推論量を変えられる。

- Modelは「どの頭脳を使うか」を決める。
- 推論強度は「その頭脳にどの程度考えさせるか」を決める。

強度を上げれば常によいわけではない。
単純な文章修正や小さなコード変更なら軽い設定で足りることがあり、複雑な設計判断や原因分析なら重い推論が役立つことがある。
その代わり、重い推論ほど時間や利用量が増える傾向があるので、タスクに合わせて選ぶ。

この区別を保つため、「GPT-5.6 Sol Max」のような表現も、Modelと強度に分けて読む。
元メモのプロジェクト内の整理では、Modelは「GPT-5.6 Sol」、強度は「max」として扱う。

## Token、Context、Context Window、Cacheを分ける

どれも入力情報に関係するが、指しているものは違う。

- **Token（トークン）**：Modelが扱う情報量を数える単位。
- **Context（コンテキスト）**：その時点でModelが判断材料として参照している情報。
- **Context Window（コンテキストウィンドウ）**：Modelが一度に扱えるContextの上限。
- **Cache（キャッシュ）**：以前に処理した入力の一部を再利用する仕組み。

Contextを「扱えるToken数の上限」と説明すると、Context Windowとの区別が崩れる。
Contextは実際に参照している情報であり、その保持できる量の上限がContext Windowである。

Cacheは長期記憶ではない。
共通の指示や繰り返し使う入力など、以前に処理した部分を再利用する仕組みである。

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

## Harnessは責務の違いで二層に分けると整理しやすい

Modelだけでは現実の仕事は完結しない。
必要なContextを集めてModelへ渡し、Toolを実行し、その結果を次の判断へ戻し、複数の作業を完了までつなぐ仕組みが要る。
この外側の仕組みが、広く **Harness（ハーネス。Modelを仕事へつなぐ外側の仕組み）** と呼ばれている。

しかし、Harnessという名前だけでは、どの範囲まで担当しているかが分からない。
そこで元メモのプロジェクトでは、責務の違いを基準に二層へ分ける。

```text
人間
  ↓
Execution Harness
  ↓
Agent Harness
  ↓
Model
```

## Execution Harnessは仕事全体を受け取り、完了まで回す

**Execution Harness** は、人間に近い側で仕事全体を受け取り、完了まで進行させる役割を持つ。
元メモのプロジェクトでは、Pi、DSH、Hermesをこの側の例として扱っている。

Execution Harnessが担うのは、単発のModel呼び出しではない。
人間から依頼を受け、必要な作業を整理し、Agent Harnessへ具体的な仕事を渡し、返ってきた結果を確認しながら次の作業へつなぐ。

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

Execution Harnessは、単なる **サンドボックス（隔離された実行環境）** や実行インフラを指す言葉としては使わない。
この分類で見ているのは、人間から受けた仕事全体を管理する責務である。

## Agent HarnessはModelとToolのループを回して具体作業を進める

**Agent Harness** は、Modelに近い側で具体的な作業を進める役割を持つ。
元メモのプロジェクトでは、Codex、Claude Code、GitHub Copilotをこの側の例として扱っている。

Agent HarnessはExecution Harnessから仕事を受けると、ContextをModelへ渡し、Modelが決めた次の行動をToolへつなぐ。
Toolの実行結果は再びContextへ入り、Modelは更新された情報で次の行動を決める。

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

ファイル調査、コード修正、コマンド実行、テストといった実作業は、このループの中で続く。
ModelとAgent Harnessは同じものではない。
Agent HarnessがModelとToolをつなぎ、一つのAgentとして作業を進める。

## 「Harnessの上にHarnessがある」構成は責務が別の層である

Execution Harnessは、一つのAgent Harnessだけを使う必要はない。
大きな仕事を複数の具体的な作業へ分け、それぞれを別のAgent Harnessへ任せる構成も取れる。

たとえば「この機能を追加して」という依頼を、既存コードの調査、実装、テストへ分ける。
Execution Harnessは全体の依頼を受け、三つの仕事を別々のAgent Harnessへ割り当て、返ってきた結果をまとめながら進める。

```text
                  ┌→ Agent Harness A → Model
人間 → Execution ├→ Agent Harness B → Model
       Harness    └→ Agent Harness C → Model
```

この構造は「Harnessの上にHarnessがある」ように見える。
実際には同じ責務を重ねているのではなく、人間側の仕事全体を管理する層と、Model側で具体作業を実行する層が分かれている。

## 両方がHarnessと呼ばれるのは、製品の中で境界が見えないからである

実際の製品では、Execution HarnessとAgent Harnessに当たる責務が一つの製品に含まれることがある。
利用者からは内部の境界が見えないので、一つのHarnessとして扱っても不自然ではない。

一方、複数のAgentや複数の製品を組み合わせる設計では、境界を分けて考えた方が責務を整理しやすい。
そのため元メモでは、一般的なHarnessという広い呼び方を残しつつ、説明上は二つに分けている。

この呼び分けは「どちらか一方だけが本物のHarnessである」という主張ではない。
同じ言葉が異なる責務範囲に使われるので、その差を明示するための整理である。

## Modelの性能だけでは実際の使い勝手は決まらない

同じModelでも、外側のHarnessによって作業の進み方は変わる。
Modelが高性能でも、人間が毎回Contextを渡し、次の操作を細かく指定し、Toolの結果を確認して再指示する構成では、人間側の作業が多く残る。

Agent HarnessがModelとToolのループを回し、Execution Harnessが複数の作業を完了までつなげれば、人間が一つずつ操作を指示する必要は減る。
ここで変わっているのはModelの知能ではなく、Modelの能力を仕事へつなぐ外側の構造である。

したがって、AI開発環境を比べるときはModel名だけでは足りない。
Model、推論強度、Agent Harness、Execution Harnessがどう組み合わされているかを分けて見ると、使い勝手の差を説明しやすい。

## 一文を分解するとこうなる

次の表現を、この分類で分解する。

> 今回の改修はLLMでやってみようと思う。
> その際に使用するのはOpenAIのCodexで、GPT-5.6 Sol MaxをHermes上で使用してみよう。

| 要素 | 該当 |
| --- | --- |
| Provider | OpenAI |
| Agent Harness | Codex |
| Model | GPT-5.6 Sol |
| 推論強度 | max |
| Execution Harness | Hermes |

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

確認すべき点は、「GPT-5.6 Sol Max」を一つのModel名として扱わず、Modelと推論強度に分けることである。

## 製品名から機械的に分類しない

この分類は、製品名から機械的に決めるための一般規格ではない。
製品の機能範囲は変わり得るので、実際の製品を比べるときは、その時点でどの責務を担っているかを確認する。

また、セキュリティ機構、サンドボックス、権限管理、監視基盤などを同じ分類軸へ混ぜない。
それらを備える製品はあり得るが、この二層分類が分けているのは「人間から仕事全体を受ける側」と「Modelを使って具体作業を進める側」という責務である。

別ノートの [[AI-DEにおけるハーネスの位置づけと設計境界|AI-DEにおけるハーネスの位置づけと設計境界]] では、UHPの整理に沿ってPi、Hermes、DeepSeek Harnessも「自前のAgent Loopを持つHarness」の例に入っている。
同じ製品が、見る観点によってExecution Harness側にもAgent Harness側にも置かれ得る、という点でもこの注意は当てはまる。

## 全体の関係図

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

## 関連

- [[ハーネスエンジニアリング|ハーネスエンジニアリング]]
- [[AI-DEにおけるハーネスの位置づけと設計境界|AI-DEにおけるハーネスの位置づけと設計境界]]
- [[サブエージェントとオーケストレーション|サブエージェントとオーケストレーション]]
- [[複数AIエージェントのオーケストレーション|複数AIエージェントのオーケストレーション]]
- [[LLMの「賢さ」と品質グラフの読み方|LLMベンチマークの読み方]]
- [[AI実行ガバナンスと人間の監督]]

## 参考資料

- 原本：[[Sources/AI Harness/AI開発の用語とハーネス階層の元資料]]
#lesson
