# AI-DEにおけるハーネスの位置づけと設計境界

Status: Researching

AI-DEを開発する中で、「AI-DEそのものがハーネスなのか」「どこまでがハーネスで、どこからが開発環境なのか」が曖昧になってきた。
当初は、CodexやClaude CodeなどのAIエージェントを動かすためのハーネスを作っている、という認識が強かった。
しかしAI-DEには、要件定義、開発計画、依存関係管理、Critical Path、Human Decision、Gate、Evidence、Replanningなど、エージェント実行そのものを超えた機能が増えている。

そこで現在は、AI-DE全体をハーネスとは捉えない。
AI-DEを **AI Development Environment（AIによる開発環境）** と捉え、その内部に **Harness Host** と **Agent Harness** があると整理する方が実態に近い。
このノートは、UHP、DeepSeek Harness、Pi AgentHarness v2、HarnessRouterを参考に、その境界を整理したものである。
ここに書いた構成は採用済みの設計ではなく、現時点の仮説である。

ハーネスという考え方そのものは [[Harness Engineering|ハーネスエンジニアリング]]、用語の階層は [[AI Development Terms and Harness Layers|AI開発の用語とハーネスの階層]] にある。

## AI-DEが管理しているのはエージェント実行ではなく開発活動の進行である

AI-DE全体は、モデルへPromptを送ってToolを実行するだけの **Runtime（実行基盤）** ではない。
現在のAI-DEは、おおむね次の責務を持つ。

```text
Human
  ↓
Requirements
  ↓
Planning / Scheduling
  ↓
Task
  ↓
Agent Execution
  ↓
Artifact / Evidence
  ↓
Gate / Human Decision
  ↓
Replanning
```

主な用語は次の意味で使う。

- **Critical Path（クリティカルパス）**：依存関係上、遅れると全体が遅れる作業の連なり。
- **Gate（ゲート）**：工程を次へ進めてよいかを判定する関門。
- **Evidence（証拠）**：作業が完了したと判断する根拠となる成果物や検査結果。
- **Human Decision**：人間が判断すべき点。
- **Replanning（再計画）**：結果を受けて計画を立て直すこと。

AI-DEが管理しているのは「エージェントの実行」だけではなく、開発活動そのものの進行である。
そのため、AI-DE全体をAgent Harnessと呼ぶと範囲が広すぎる。

```text
AI-DE
= AI Development Environment

  Development Runtime
+ Harness Host
+ Agent Harness
```

AI-DEという名前が、ようやく実態として「AIとIDE」「AI Development Environment」に近づいてきたと考えている。

## UHPはハーネスの境界を考えるための共通語彙になる

**UHP（Unified Harness Protocol）** は、HarnessRouterプロジェクトが公開している、Agent HarnessをApplicationから共通の方法で操作するための **Protocol（通信や操作の取り決め）** である。

現時点では業界標準ではなく、位置づけは **Draft standard（標準案）** である。
ただし、アイデアや提案だけではなく、次のものまで提供されている。

- Versioned Specification
- OpenAPI
- JSON Schema
- Conformance Suite（準拠しているかを確かめるテスト群）
- Governance
- Versioning Rules
- Reference Implementation（参照実装）

正式な業界標準としては扱えないが、ハーネスの境界を考える共通語彙としては十分に使える。

## UHPはClient、Server、Harnessの三層を分ける

```text
Client
  ↓ UHP
Server
  ↓ implementation-defined
Harness
```

- **Client**：Harnessへ仕事を依頼する側。Product Backend、CLI、CI、別のエージェントなどが該当する。ClientはHarness内部の実装方法を知る必要がない。
- **Server**：UHPを実装し、Harnessを起動・操作する側。Task実行、Session継続、Streaming、Cancel、Artifact取得などを共通契約として提供する。Container、Subprocess、Queue、Remote Workerなど、Harnessをどう実行するかはServer側の実装責務になる。
- **Harness**：自身のAgent Loop、Tools、Session Stateを持つ完全なAgent Runtime。例はCodex、Claude Code、Hermes、Pi、DeepSeek Harness。

UHPはHarness内部の設計方法を規定しない。
規定するのは、ApplicationからHarnessをどう操作するかという境界である。

なお、[[AI Development Terms and Harness Layers|AI開発の用語とハーネスの階層]] ではPi、DSH、HermesをExecution Harness側の例として扱っている。
UHPの観点では、これらも「自前のAgent Loopを持つHarness」に入る。
同じ製品でも、どの境界で見るかによって置き場所が変わる点に注意する。

## AI-DEは「Development Runtime / Harness Host / Agent Harness」の三層で捉える

UHPの境界をAI-DEへ当てはめると、次の構造になる。

```text
┌─────────────────────────────────────┐
│ AI-DE Development Runtime           │
│                                     │
│ Requirements / Governance           │
│ State Store                         │
│ Planning / Scheduling               │
│ Dependency / Critical Path          │
│ Human Decision / Gate               │
│ Replanning                          │
│                                     │
│ UHP Client相当                       │
└─────────────────┬───────────────────┘
                  │
             Harness Boundary
                  │
                  ▼
┌─────────────────────────────────────┐
│ Harness Host                        │
│                                     │
│ Harness Selection                   │
│ Session Management                  │
│ Worker / Sandbox                    │
│ Provider / CLI Adapter              │
│ Streaming / Cancel / Resume         │
│ Artifact Transfer                   │
│ Crash Recovery                      │
│                                     │
│ UHP Server相当                       │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│ Agent Harness                       │
│                                     │
│ Agent Loop                          │
│ Context                             │
│ Model                               │
│ Tools                               │
│ Skills / MCP                        │
│ Permissions / Capability            │
│ Subagent                            │
│ Agent Session State                 │
└─────────────────────────────────────┘
```

この境界で考えると、「AI-DEはHarnessなのか」という問いにはこう答えられる。

> AI-DE全体はHarnessではない。
> AI-DEという開発環境の中に、Harness HostとAgent Harnessが存在する。

## 「何を、なぜ、どの順序で開発するか」はハーネスに含めない

次の領域はAgent Harnessではなく、AI-DEの **Development Runtime** として扱う。

- Requirements
- Acceptance Criteria（受け入れ条件）
- QA
- Governance
- GitHub Issues同期
- Project
- WorkItem
- Dependency
- Critical Path
- Conflict Risk
- Planning / Scheduling
- Worker Assignmentの計画
- Replanning
- Human Decision
- Gate
- Evidenceの評価
- 開発プロセス全体の **Authority（正しい状態を決める権限）**

これらが扱っているのは「エージェントをどう動かすか」ではない。
「何を、なぜ、どの順序で開発するか」という開発計画そのものである。

## Agent Harnessは実際にエージェントを動かす部分である

主な責務は次のとおり。

- Agent Loop
- Context Management
- Model
- Thinking / Reasoning設定
- Tool
- Tool Execution
- Skill
- **MCP（Model Context Protocol。外部の道具やデータをエージェントへつなぐ仕組み）**
- Permission
- Capability
- Subagent
- Agent Session State

UHPの **Configured Harness（設定済みのHarness）** でも、次の設定がHarness側の要素として扱われる。

- Default Model
- System Prompt
- MCP Servers
- Skills
- Disabled Tools
- Step Budget
- Timeout

このため、Model選択やSkillの設定は、基本的にHarness Configurationとして扱うのが自然である。

## Harness HostはAgent Harnessを起動・管理する中間層である

AI-DEの現在のExecution Runtimeをすべて「Agent Harness」と呼ぶと範囲が広すぎる。
Agent Harnessの外側には、Harnessを起動して管理する実行基盤がある。
この層をAI-DEでは **Harness Host** と呼ぶ。

責務の例は次のとおり。

- Harness選択
- Harness起動
- Session管理
- Worker起動
- Workspace管理
- Sandbox
- Provider / CLI Adapter
- Streaming
- Cancel
- Resume
- Artifact回収
- Crash Recovery
- Harnessごとの差異吸収

UHPでいうServerに近いが、AI-DE内部で必ずUHP準拠になるとは限らない。
そのため内部名称はHarness Hostとする。

## State Storeは保存先が同じでもAuthorityで分ける

現在のAI-DE State Storeには、開発プロセスの状態とエージェント実行の状態が混在している。
保存先を分ける必要はないが、Authorityとしては分けて考える。

```text
AI-DE State

├─ Development State
│  ├─ Project
│  ├─ WorkItem
│  ├─ Requirement
│  ├─ Task
│  ├─ Gate
│  ├─ Decision
│  └─ Evidence
│
└─ Harness Execution State
   ├─ Harness Session ID
   ├─ Response / Run
   ├─ Conversation
   ├─ Tool State
   └─ Resume State
```

- Development Stateは、AI-DEがAuthorityを持つ。
- Harness Execution Stateは、HarnessまたはHarness Hostが持つ状態と、AI-DE側の **Attempt（開発上の試行）** を関連付ける。

## TaskとHarness Runは同じ単位ではない

AI-DEのTaskと、Harnessへ発行するRunやResponseは別の単位である。

```text
AI-DE Task
「認証機能を実装する」

  ↓ Attempt #1

Harness Run
  ↓
Failure

  ↓ Attempt #2

Harness Run
  ↓
Success
```

| 単位 | 管理する側 |
| --- | --- |
| Task | AI-DE |
| Attempt | AI-DE |
| Harness Run / Response | Harness |
| Harness Session | Harness |

AI-DEは「開発上の試行」を管理し、Harnessは「一回のエージェント実行」を管理する。

## DeepSeek Harnessは「Harnessをどう組み替えるか」に強い

**DeepSeek Harness（DSH）** は、Agent Harness側の構成可能性に強い。

- Everything is Plugin
- Agent LoopまでPlugin化
- Tool、Session、Model AdapterなどもPlugin化
- Subagent Runtime
- Provider / Modelの動的切替
- CordisによるPlugin管理
- Componentを実行中に差し替えられる設計

DSHの下では、Plugin Frameworkとして [[Cordis]] が使われる。
Cordisは [[Spatiotemporal Composability]] という考え方を持つ。
そのうち **Temporal Composability（時間方向の合成可能性）** では、PluginがRuntimeへ加えた **Effect（副作用）** と、それを取り消す **Inverse（逆操作）** を管理する。

```text
Plugin Load

Listener追加
Timer開始
Tool登録

↓ unload

Tool解除
Timer停止
Listener解除
```

ただし、メール送信や外部DB更新など、Cordis管理外で起きた外部Effectまで自動で巻き戻せるわけではない。
Cordis管理下のEffectについて、cleanupを構造化して追跡する仕組みと理解する。
この限界は [[System Boundary and Recoverability]] の問題でもある。

## Pi AgentHarness v2は「壊れずに実行し続ける」ことに強い

**Pi AgentHarness v2** は、DSHとは別の方向に強い。
中心テーマは **Durable Execution（永続的な実行。途中で落ちても続きから実行できること）** であり、「エージェントの仕事をどう壊れず実行し続けるか」を重視している。

主な特徴は次のとおり。

- Durable Run
- Crash Recovery
- Resume
- Lane
- Parallel Lane Execution
- Tool Replay Safety
- Steering
- Follow-up
- Next-run
- Deferred Provider Request
- Session永続化
- Effect Boundary
- Manual Drive
- Crash Siteを決定的にテストする

### Intent → Effect → Result

Pi Harness v2で特に重要な設計である。

```text
Intentを永続化
    ↓
Effectを実行
    ↓
Resultを永続化
```

Effectを実行する前にIntent（これから何をするか）を保存する。
Crashした場合、「Intentあり、Resultなし」の記録を見れば、中断された処理を判定できる。

### Tool Replay Safety

Tool自身が再実行してよいかを宣言する。

```text
replay = safe
→ Crash後に再実行可能

replay = never
→ 再実行せずInterrupted Resultを生成
```

これで外部Effectを二重実行する危険を抑える。

### Lane

一つのSessionの中に複数のLaneを持つ。

```text
Conversation Tree

        ┌─ Lane A
a - b - c
        └─ Lane B
```

各Laneは独立したOperation Log、Queue、Model設定などを持ち、並列で実行できる。
Subagent用のRuntime Primitiveとしても使える。

## HarnessRouterはHarnessの統一操作であり、機能の合成ではない

**HarnessRouter** はAgent Harnessそのものではない。
複数のAgent Harnessを同じAPIから操作するための **Gateway（入口）** ／Runtime管理層である。
UHPのReference Implementationでもある。

```text
Application
    ↓
HarnessRouter
    ├─ Codex
    ├─ Claude Code
    ├─ Hermes
    ├─ Pi
    ├─ DSH
    └─ ...
```

吸収する主な差異は次のとおり。

- Task開始
- Session
- Streaming
- Cancel
- Artifact
- Error
- Recovery関連API
- Harness Discovery

一つのエージェント実行では、基本的にPiかDSHなど一つのHarness Runtimeを選ぶ。
HarnessRouterを使えば、Task単位で選べる。

```text
AI-DE
  ↓
HarnessRouter
  ├─ Pi
  ├─ DSH
  ├─ Codex
  └─ Claude Code
```

ただし、HarnessRouterを入れても「PiのDurability」と「DSHのEverything is Plugin」が一つのHarnessへ自動で合成されるわけではない。
HarnessRouterが行うのはHarnessの統一操作であり、Harness内部機能の合成ではない。

## 「いいとこどり」には二種類ある

| 種類 | 例 | 実現方法 |
| --- | --- | --- |
| Task単位のいいとこどり | Task A→Pi、Task B→DSH、Task C→Codex | HarnessRouterなどで実現しやすい |
| Harness内部でのいいとこどり | PiのDurable Execution＋DSHのPlugin Architecture＋AI-DE独自のPlanning連携 | HarnessRouterでは実現できない。自前のAI-DE Harnessへ設計思想を取り込む必要がある |

## 自前のAI-DE Harnessはすぐには捨てない

外部Harnessを調べた結果、自前Harnessを直ちに捨てる必要はないと考えている。
AI-DEには、一般的なAgent HarnessにはないDevelopment Runtimeとの接続がある。

```text
Planning
   ↓
Harness Execution
   ↓
Artifact / Evidence
   ↓
Development State
   ↓
Replanning
```

AI-DE Harnessの独自性は、単純なエージェント実行ではなく、Development PlanningとAgent Executionを接続することに置ける可能性がある。

外部OSSに勝つために、すべてを再実装する必要はない。
Pi、DSH、HarnessRouterなどの優れた設計を研究し、必要なものを取り込めばよい。

## Task難易度によってSubagentを選びたい

AI-DEで重要と考えている機能である。
役割ごとに固定のエージェントを割り当てるのではなく、Taskの難易度に応じて、設定済みのエージェントやモデルを選ぶ。

```text
easy
→ lightweight

normal
→ standard

hard
→ strong
```

DeepSeek HarnessやKimi Codeなどには、この考え方に近い動的モデル選択機能がある。
この機能をどの層に持たせるかは未決定である（候補は後述）。
サブエージェントの使い分けは [[Subagents and Orchestration|サブエージェントとオーケストレーション]] とも関係する。

## Planning AuthorityとHarness Authorityの境界を決める必要がある

AI-DEが実行計画をどこまで決めるかで、Harness側の自律性が変わる。

### 案A：AI-DEはHarnessだけ選ぶ

```text
AI-DE
 ↓
「DSHでこのTaskを実行」

DSH
 ↓
Subagent / Model / Reasoningを判断
```

### 案B：AI-DEが実行構成まで決める

```text
AI-DE
 ↓
Harness = DSH
Model = Strong
Reasoning = High
Subagent = 3
```

## Harnessを途中で切り替えるのは別問題である

「Piで開始し、途中からDSHへ切り替える」ような実行は難しい。
Harnessごとに、Conversation State、Tool State、Operation Log、Session、Resume情報が異なるため、完全なResume互換は難しい。

必要なら、AI-DE側で再構成する仕組みを考える。

```text
Harness A
 ↓
AI-DE共通Checkpoint
 ↓
Harness Bで新しいRunを開始
```

現時点では必須機能とはしない。

## UHPに完全準拠しなくても、境界を近づける価値はある

UHPへ完全準拠するかは未決定である。
ただしHarness BoundaryをUHPに近い形で設計しておけば、将来次の利点がある。

- HarnessRouterとの接続
- 外部Harnessの利用
- 自前Harnessとの交換
- HarnessのA/B比較
- 新しいHarnessへの対応
- ApplicationとHarnessの疎結合化

完全準拠しなくても、用語と境界設計の参考として利用する価値は高い。

## AI-DE Harnessへ取り込む価値がある設計

### Piから

- Durable Operation
- Intent → Effect → Result
- Crash Recovery
- Resume
- Tool Replay Safety
- Lane
- Snapshot + Event
- Effect Boundary
- Crash Siteを決定的にテストする仕組み

### DeepSeek Harnessから

- Everything is Plugin
- Agent LoopのComponent化
- Subagent Runtime
- Model / Providerの動的選択
- CapabilityとしてのAgent
- Plugin差し替え
- Cordis的なEffect管理

### HarnessRouter / UHPから

- Client / Server / Harnessの境界
- Harness Discovery
- Configured Harness
- Capability Discovery
- Task / Session / Artifactの共通契約
- Harnessの差異を上位へ漏らさない設計

## 現時点の仮説

自前Harnessを廃止するより、AI-DE内部でHarness部分を明確に定義し直した方がよい。

```text
AI-DE
│
├─ Development Runtime
│
├─ Harness Boundary
│
├─ Harness Host
│
└─ Agent Harness
```

外部OSSは競合としてだけ見ない。
次のように扱う。

- そのまま接続する候補
- 一部機能を委譲する候補
- 設計思想を取り込む研究対象

AI-DE Harnessは、Development Runtimeとの接続に最適化されたHarnessとして磨いていく。

一文にまとめると、現在の理解は次のとおりである。

> AI-DEは「Agent Harnessそのもの」ではなく、AIによる開発活動全体を管理するDevelopment Environmentであり、その内部にDevelopment Runtime、Harness Host、Agent Harnessを持つ。

## 現時点で決めていないこと

- 自前Harnessを廃止するか
- UHPへ完全準拠するか
- HarnessRouterを採用するか
- Piを利用するか
- DeepSeek Harnessを利用するか
- Pi / DSHの設計をどこまで自前Harnessへ取り込むか
- Task難易度判定をどの層に置くか（候補：AI-DE Planning、AI-DE Harness Host、Agent Harness内部、専用Router）
- Planning AuthorityとHarness Authorityの境界（案A / 案B）
- Harness間のSession移行を実装するか
- Development StateとHarness Execution Stateの物理的な保存先を分けるか

## 関連

- [[Harness Engineering|ハーネスエンジニアリング]]
- [[AI Development Terms and Harness Layers|AI開発の用語とハーネスの階層]]
- [[AI Projects Overview|AIプロジェクトの概要]]
- [[Cordis]]
- [[Spatiotemporal Composability]]
- [[System Boundary and Recoverability]]
- [[Subagents and Orchestration|サブエージェントとオーケストレーション]]
- [[Multi-Agent Orchestration|複数AIエージェントのオーケストレーション]]
- [[AI実行ガバナンスと人間の監督]]
- [[Docker Sandboxes|Docker Sandboxes]]
- [[Issue-Driven Development|Issue駆動開発]]

## 参考資料

- HarnessRouter, Unified Harness Protocol
- https://github.com/HarnessRouter/harnessrouter/tree/main/protocol
- earendil-works/pi, *Harness v2*
- https://github.com/earendil-works/pi/blob/harness-v2/j4/packages/agent/docs/harness-v2.md
- 原本：[[Sources/AI Harness/AI-DE_ハーネス設計_ナレッジ]]
#lesson
