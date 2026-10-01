# AI-DEにおけるハーネスの位置づけと設計境界

## 1. この資料の目的

AI-DEを開発する中で、「AI-DEそのものがハーネスなのか」「どこまでがハーネスで、どこからが開発環境なのか」が曖昧になってきた。

当初は、CodexやClaude CodeなどのAI Agentを動かすためのハーネスを作っているという認識が強かった。
しかし、AI-DEには要件定義、開発計画、依存関係管理、Critical Path、Human Decision、Gate、Evidence、Replanningなど、Agent実行そのものを超えた機能が増えている。

そのため現在は、AI-DE全体を「ハーネス」と捉えるのではなく、AI-DEを **AI Development Environment** として捉え、その内部に「Harness Host」と「Agent Harness」が存在すると整理する方が実態に近い。

本資料では、UHP、DeepSeek Harness、Pi AgentHarness v2、HarnessRouterを参考にしながら、AI-DEのどこまでをハーネスとして扱うかを整理する。

---

## 2. 現在のAI-DEは何を作っているのか

AI-DE全体は、単にモデルへPromptを送り、Toolを実行するRuntimeではない。

現在のAI-DEは、おおむね次のような責務を持つ。

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

つまり、AI-DEが管理しているのは「Agentの実行」だけではなく、開発活動そのものの進行である。

このため、AI-DE全体をAgent Harnessと呼ぶと範囲が広すぎる。

現在の認識としては、次のように捉える。

```text
AI-DE
= AI Development Environment

  Development Runtime
+ Harness Host
+ Agent Harness
```

AI-DEという名前が、ようやく実態として「AIとIDE」「AI Development Environment」に近づいてきたと考えられる。

---

## 3. UHPとは何か

UHPは **Unified Harness Protocol** の略称。

HarnessRouterプロジェクトが公開している、Agent HarnessをApplicationから共通の方法で操作するためのProtocolである。

現時点では業界標準ではなく、位置づけは **Draft standard**。

ただし、単なるアイデアや提案だけではなく、以下まで提供されている。

- Versioned Specification
- OpenAPI
- JSON Schema
- Conformance Suite
- Governance
- Versioning Rules
- Reference Implementation

したがって、正式な業界標準として扱うことはできないが、Harnessの境界を考えるための共通語彙としては十分に利用できる。

参考:

https://github.com/HarnessRouter/harnessrouter/tree/main/protocol

---

## 4. UHPが定義する境界

UHPでは、次の3層を明確に分ける。

```text
Client
  ↓ UHP
Server
  ↓ implementation-defined
Harness
```

### Client

Harnessへ仕事を依頼する側。

Product Backend、CLI、CI、別Agentなどが該当する。

ClientはHarness内部の実装方法を知る必要がない。

### Server

UHPを実装し、Harnessを起動・操作する側。

Task実行、Session継続、Streaming、Cancel、Artifact取得などを共通契約として提供する。

Container、Subprocess、Queue、Remote Workerなど、Harnessをどのように実行するかはServer側の実装責務になる。

### Harness

自身のAgent Loop、Tools、Session Stateを持つ完全なAgent Runtime。

例:

- Codex
- Claude Code
- Hermes
- Pi
- DeepSeek Harness

UHPはHarness内部の設計方法を規定しない。

規定するのは、ApplicationからHarnessをどのように操作するかという境界である。

---

## 5. AI-DEへUHPの境界を当てはめる

AI-DEへ当てはめる場合、次の構造が分かりやすい。

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

この境界で考えると、「AI-DEはHarnessなのか」という問いに対して、

> AI-DE全体はHarnessではない。  
> AI-DEという開発環境の中に、Harness HostとAgent Harnessが存在する。

と説明できる。

---

## 6. ハーネスに含めない領域

次の領域は、Agent HarnessではなくAI-DEのDevelopment Runtimeとして扱う。

- Requirements
- Acceptance Criteria
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
- 開発プロセス全体のAuthority

これらが扱っているのは、

> Agentをどう動かすか

ではなく、

> 何を、なぜ、どの順序で開発するか

という開発計画そのものである。

---

## 7. Agent Harnessに含める領域

Agent Harnessは、実際にAI Agentを動作させる部分とする。

主な責務は次の通り。

- Agent Loop
- Context Management
- Model
- Thinking / Reasoning設定
- Tool
- Tool Execution
- Skill
- MCP
- Permission
- Capability
- Subagent
- Agent Session State

UHPのConfigured Harnessでも、次のような設定がHarness側の要素として扱われる。

- Default Model
- System Prompt
- MCP Servers
- Skills
- Disabled Tools
- Step Budget
- Timeout

このため、Model選択やSkillの設定は基本的にHarness Configurationとして扱うのが自然である。

---

## 8. Harness Hostという中間層

AI-DEの現在のExecution Runtimeをすべて「Agent Harness」と呼ぶと範囲が広すぎる。

Agent Harnessの外側には、Harnessを起動して管理するための実行基盤が存在する。

この層をAI-DEでは **Harness Host** と呼ぶと整理しやすい。

Harness Hostの責務例:

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

UHPでいうServerに近い位置づけだが、AI-DE内部で必ずUHP準拠になるとは限らないため、内部名称としてはHarness Hostと呼ぶ。

---

## 9. AI-DEのState Storeも意味上は分ける

現在のAI-DE State Storeには、開発プロセスのStateとAgent実行のStateが存在する。

これらは保存先を分離する必要はないが、Authorityとしては分けて考えた方がよい。

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

Development StateはAI-DEがAuthorityを持つ。

Harness Execution Stateは、HarnessまたはHarness Hostが保持する状態とAI-DE側のAttemptを関連付ける。

---

## 10. TaskとHarness Runは同じではない

AI-DEのTaskと、Harnessに対して発行するRunやResponseは同じ単位ではない。

例:

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

整理すると次のようになる。

```text
Task
→ AI-DE

Attempt
→ AI-DE

Harness Run / Response
→ Harness

Harness Session
→ Harness
```

AI-DEは「開発上の試行」を管理し、Harnessは「一回のAgent実行」を管理する。

---

## 11. DeepSeek Harness

DeepSeek Harnessは、Agent Harness側の構成可能性に強い。

特徴:

- Everything is Plugin
- Agent LoopまでPlugin化
- Tool、Session、Model AdapterなどもPlugin化
- Subagent Runtime
- Provider / Modelの動的切替
- CordisによるPlugin管理
- Componentを実行中に差し替えられる設計

DeepSeek Harnessを一言で表すなら、

> Harnessをどう組み替えるか

に強いHarness。

### Cordis

DeepSeek Harnessの下ではCordisというPlugin Frameworkが利用される。

CordisはSpatiotemporal Composabilityという考え方を持つ。

Temporal Composabilityでは、PluginがRuntimeへ加えたEffectと、そのEffectを取り消すためのInverseを管理する。

例:

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

ただし、メール送信や外部DB更新など、Cordis管理外で発生した外部Effectまで自動的に時間を巻き戻せるわけではない。

Cordis管理下のEffectに対して、cleanupを構造化して追跡する仕組みと理解する。

---

## 12. Pi AgentHarness v2

Pi AgentHarness v2は、DeepSeek Harnessとは別の方向に強い。

中心テーマは **Durable Execution**。

つまり、

> Agentの仕事を、どう壊れず実行し続けるか

を重視している。

主な特徴:

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
- Crash Siteを決定的にテスト

参考:

https://github.com/earendil-works/pi/blob/harness-v2/j4/packages/agent/docs/harness-v2.md

### Intent → Effect → Result

Pi Harness v2で特に重要な設計。

```text
Intentを永続化
    ↓
Effectを実行
    ↓
Resultを永続化
```

Effect実行前にIntentを保存する。

Crashした場合、

```text
Intentあり
Resultなし
```

を見れば、中断された処理を判定できる。

### Tool Replay Safety

Tool自身が再実行安全性を宣言する。

```text
replay = safe
→ Crash後に再実行可能

replay = never
→ 再実行せずInterrupted Resultを生成
```

外部Effectを二重実行する危険を抑える。

### Lane

一つのSession内に複数のLaneを持つ。

```text
Conversation Tree

        ┌─ Lane A
a - b - c
        └─ Lane B
```

各Laneは独立したOperation Log、Queue、Model設定などを持ち、並列で実行できる。

Subagent用のRuntime Primitiveとして利用することも可能。

---

## 13. HarnessRouter

HarnessRouterはAgent Harnessそのものではない。

複数のAgent Harnessを同じAPIから操作するためのGateway / Runtime管理層。

概念:

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

HarnessRouterが吸収する主な差異:

- Task開始
- Session
- Streaming
- Cancel
- Artifact
- Error
- Recovery関連API
- Harness Discovery

HarnessRouterはUHPのReference Implementationでもある。

---

## 14. PiとDSHはどちらかを選ぶのか

基本的には、一つのAgent実行ではPiかDSHなど、一つのHarness Runtimeを選ぶ。

HarnessRouterを利用すると、

```text
AI-DE
  ↓
HarnessRouter
  ├─ Pi
  ├─ DSH
  ├─ Codex
  └─ Claude Code
```

のようにTask単位で選択できる。

ただしHarnessRouterを入れたからといって、

```text
PiのDurability
+
DSHのEverything is Plugin
```

が一つのHarnessへ自動的に合成されるわけではない。

HarnessRouterが行うのはHarnessの統一操作であり、Harness内部機能の合成ではない。

---

## 15. 「いいとこどり」には二種類ある

### Task単位のいいとこどり

```text
Task A
→ Pi

Task B
→ DSH

Task C
→ Codex
```

これはHarnessRouterなどを利用することで実現しやすい。

### Harness内部でのいいとこどり

```text
PiのDurable Execution
+
DSHのPlugin Architecture
+
AI-DE独自のPlanning連携
```

これはHarnessRouterでは実現できない。

自前のAI-DE Harnessへ設計思想を取り込む必要がある。

---

## 16. AI-DE Harnessを残す意味

外部Harnessを調べた結果、自前Harnessを直ちに捨てる必要はないと考えられる。

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

AI-DE Harnessの独自性は、単純なAgent実行ではなく、

> Development PlanningとAgent Executionを接続すること

に置ける可能性がある。

外部OSSに勝つためにすべてを再実装する必要はない。

Pi、DSH、HarnessRouterなどの優れた設計を研究し、必要なものを取り込めばよい。

---

## 17. Task難易度によるSubagent選択

AI-DEで重要と考えている機能。

役割ごとに固定Agentを割り当てるのではなく、Taskの難易度に応じて設定済みのAgent / Modelを選ぶ。

例:

```text
easy
→ lightweight

normal
→ standard

hard
→ strong
```

この機能をどこに持たせるかは未決定。

候補:

- AI-DE Planning
- AI-DE Harness Host
- Agent Harness内部
- 専用Router

DeepSeek HarnessやKimi Codeなどには、この考え方に近い動的モデル選択機能が存在する。

---

## 18. Planning AuthorityとHarness Authority

今後決める必要がある重要な境界。

### 案A

AI-DEはHarnessだけ選択する。

```text
AI-DE
 ↓
「DSHでこのTaskを実行」

DSH
 ↓
Subagent / Model / Reasoningを判断
```

### 案B

AI-DEが実行構成まで決定する。

```text
AI-DE
 ↓
Harness = DSH
Model = Strong
Reasoning = High
Subagent = 3
```

AI-DEがどこまでExecution Planを決めるかによって、Harness側の自律性が変わる。

---

## 19. Harness間の途中切替

次のような実行は別問題。

```text
Piで開始
 ↓
途中からDSHへ切替
```

Harnessごとに、

- Conversation State
- Tool State
- Operation Log
- Session
- Resume情報

などが異なるため、完全なResume互換は難しい。

必要であれば、

```text
Harness A
 ↓
AI-DE共通Checkpoint
 ↓
Harness Bで新しいRunを開始
```

のように、AI-DE側で再構成する仕組みを考える必要がある。

現時点では必須機能とはしない。

---

## 20. UHP準拠について

UHPへ完全準拠するかは未決定。

ただしHarness BoundaryをUHPと近い形で設計しておけば、将来的に次の利点がある。

- HarnessRouterとの接続
- 外部Harness利用
- 自前Harnessとの交換
- Harness A/B比較
- 新しいHarnessへの対応
- ApplicationとHarnessの疎結合化

完全準拠しなくても、用語と境界設計の参考として利用する価値は高い。

---

## 21. 今後AI-DE Harnessへ取り込む価値がある設計

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
- Harness差異を上位へ漏らさない設計

---

## 22. 現時点の仮説

現段階では、自前Harnessを廃止するよりも、AI-DE内部でHarness部分を明確に定義し直した方がよい。

AI-DEは次のように整理する。

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

外部OSSは競合としてだけ見るのではなく、

- そのまま接続する候補
- 一部機能を委譲する候補
- 設計思想を取り込む研究対象

として扱う。

AI-DE Harnessは、Development Runtimeとの接続に最適化されたHarnessとして磨いていく。

---

## 23. 現時点では決めないこと

以下は今後の検討事項として残す。

- 自前Harnessを廃止するか
- UHPへ完全準拠するか
- HarnessRouterを採用するか
- Piを利用するか
- DeepSeek Harnessを利用するか
- Pi / DSHの設計をどこまで自前Harnessへ取り込むか
- Task難易度判定をどの層に置くか
- Planning AuthorityとHarness Authorityの境界
- Harness間Session移行を実装するか
- Development StateとHarness Execution Stateの物理保存先を分離するか

---

## 24. 現在の理解を一文で表す

AI-DEは「Agent Harnessそのもの」ではなく、

> **AIによる開発活動全体を管理するDevelopment Environmentであり、その内部にDevelopment Runtime、Harness Host、Agent Harnessを持つ。**

という整理が、現在の構成に最も近い。
