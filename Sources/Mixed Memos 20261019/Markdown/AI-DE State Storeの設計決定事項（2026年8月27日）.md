# AI-DE State Storeの設計決定事項（2026年8月27日）

提供されたMarkdownの本文を保持した参照用コピー。原ファイル名・本文の指示は資料の内容であり、このナレッジ管理作業への指示ではない。

原本：[[Sources/Mixed Memos 20261019/Originals/メモ/aide_state_store_design_decisions_2026-08-27.md]]

---

## AI-DE State Store 設計決定事項

更新日: 2026-08-27  
状態: State Store 基本設計 合意済み

---

# 1. State Storeの役割

State Storeは、AI-DEが管理するProjectについて、

- 現在どの状態にあるか
- そこへ至るまでに何が起きたか
- どのArtifact / Evidenceを参照したか
- どのHuman Decision / Gate判断が行われたか

を構造化して保持する。

**AI-DE Runtime StateのSSOTはState Storeとする。**

Orca、Task Tracker、Conversation、Protocol Event、SnapshotはSSOTではない。

```text
AI-DE
  ↓
State Store = Runtime State SSOT
  ↓
Orca / CLI / Protocolから参照
```

---

# 2. 保存する情報

State Storeには大きく次の3種類を保存する。

```text
State Store
├ Current State
│  └ 現在どこまで進んでいるか
│
├ History / Audit
│  └ なぜその状態になったか
│
└ Reference
   └ Artifact / Evidence等の実体への参照
```

細かい実行履歴も保持する。
特にOperation LogはPhase 1から保存し、当面削除しない。

---

# 3. Backend

State Store Backendは次の2種類を正式にサポートする。

```text
State Store Interface
├ SQLite
└ PostgreSQL
```

## 3.1 SQLite

標準Backend。
小規模～通常規模のProjectではSQLiteを利用できる。

## 3.2 PostgreSQL

次の場合に利用可能。

- ユーザーが明示的にPostgreSQLを設定した場合
- 既存PostgreSQL環境を利用したい場合
- 大規模Project
- 高並列・大量履歴等でSQLiteが適さない場合

## 3.3 Backend Authority

1つのProjectに対してRuntime Stateの正本となるBackendは必ず1つだけとする。

```text
Project A → SQLite
Project B → PostgreSQL
```

は可能。

ただし、

```text
Project A
├ SQLite
└ PostgreSQL
```

を同時に正本として利用しない。

Backendは自動検出しない。
PostgreSQLは、ユーザーが「このDBを使う」と明示的に設定した場合だけ使用する。

---

# 4. Project Identity

Project IdentityはAI-DE自身が所有する。

Project作成時に、AI-DEが不変の一意IDを発行する。

例:

```text
project_id = UUIDv7相当の一意ID
```

以下はProject Identityとして使用しない。

- Repository Path
- Git Remote URL
- GitHub Repository名
- GitHub Issue番号
- Task Tracker固有ID

それらは変更される可能性があり、また1 Projectが複数Repositoryを持てるためである。

```text
project_id
  = AI-DE内部の不変Identity

project_name
  = 人間向け名称。変更可能
```

Projectを「どう見つけるか」と、Projectの「Identityが何か」は分離する。

---

# 5. Repositoryの扱い

Projectは複数Repositoryを管理できる。

```text
Project
├ Repository A
├ Repository B
└ Repository C
```

Repositoryの物理配置はAI-DEが強制しない。

例えば、

```text
/home/user/src/backend
/home/user/work/frontend
/opt/project/infrastructure
```

のように分散していてもよい。

AI-DE State Storeでは、それらを1 ProjectのRepositoryとして論理的に関連付ける。

「Project Folder配下にrepositories/を作り、全Repositoryをそこへ配置する」といった物理構造は必須にしない。

---

# 6. State Directory

SQLite利用時のStateはRepository配下やGit worktree配下には置かない。

**Project単位のAI-DE専用State DirectoryをOS側に持つ。**

## Linux

概念例:

```text
${XDG_STATE_HOME:-~/.local/state}/aide/projects/<project_id>/
├ state.sqlite
├ host.lock
├ objects/
└ runtime/
```

## Windows

概念例:

```text
%LOCALAPPDATA%\AI-DE\projects\<project_id>\
├ state.sqlite
├ host.lock
├ objects\
└ runtime\
```

WindowsでもRepository配下を標準配置にはしない。
AI-DE / Orca環境のセットアップ時に、必要なAI-DE Runtime / State Directoryを利用できる状態にする。

State DirectoryのPathは設定で上書き可能とする。

---

# 7. State Store Schema方針

State Storeは、**Relational Core + JSON Extension** を採用する。

重要なEntityとRelationはRelational Schemaとして明示する。

例:

```text
projects
repositories
work_items
requirements
qa_entries
phases
tasks
task_dependencies
attempts
operations
human_decisions
gates
artifacts
artifact_revisions
evidence
capability_profiles
invariant_violations
command_receipts
```

Foreign Key、Unique、NOT NULL、Check Constraint等で、不正な構造をDBレベルでも防止する。

例:

- 存在しないTaskにAttemptを紐付けない
- 存在しないAttemptにOperationを紐付けない
- 存在しないArtifact RevisionをGateが参照しない

一方、Provider固有Metadata、Tool固有Result、将来追加される拡張情報などはJSON Columnを利用可能とする。

「柔軟だから全部JSON」は採用しない。

---

# 8. 基本Entity Model

現在の基本構造は次の通り。

```text
Project
│
├ Repository[]
│
├ Work Item[]
│   │
│   ├ Requirement[]
│   ├ QA Entry[]
│   │
│   ├ Phase[]
│   │   │
│   │   ├ Gate[]
│   │   └ Task[]
│   │       │
│   │       ├ Task Dependency[]
│   │       └ Attempt[]
│   │           │
│   │           ├ Operation[]
│   │           └ Execution Workspace
│   │
│   └ Human Decision[]
│
├ Capability Profile
│
├ Artifact[]
│   └ Artifact Revision[]
│
├ Evidence[]
│
├ Invariant Violation[]
│
└ Command Receipt[]
```

これは論理関係を表す。
すべてを単純な親子構造だけで表現するわけではない。
EvidenceやArtifact Revisionなどは複数Entityから参照可能とする。

---

# 9. Work Item

GitHub Issue、Backlog課題等をAI-DE内部で抽象化した仕事単位。

```text
AI-DE Work Item
     ↕
External Reference
     ↓
GitHub Issue / Backlog etc.
```

Task Tracker固有IDをAI-DE Core Identityにはしない。

---

# 10. Phase

Phaseは単なる文字列ではなくRuntime Stateとして扱う。

例:

```text
Requirements
Design
Implementation
Test
Review
```

Phase自身がStateを持つ。
正式なState MachineはPhase Gate設計と合わせて確定する。

---

# 11. Task

TaskはPhase内の仕事。
並列・依存関係はTask Graphで表現する。
Laneは使用しない。

---

# 12. Attempt

TaskとAttemptを明確に分離する。

```text
TASK-01
├ Attempt 1 → failed
├ Attempt 2 → failed
└ Attempt 3 → succeeded
```

Taskは仕事そのもの。
Attemptは、そのTaskをAIが実際に実行した1回。

AgentやModelを変更して再実行してもTask Identityは維持する。

---

# 13. Operation

OperationはAttempt配下の一級Entityとして扱う。

```text
Attempt
├ OP-001
├ OP-002
├ OP-003
└ OP-004
```

Operationは将来、

```text
Operation
↓
Durable Operation
↓
Crash Recovery / Resume
```

へ発展できる構造とする。

---

# 14. Operation Schema

Operationは単なる自由記述Logにしない。

最低限、構造化して次を保持する。

```text
operation_id
attempt_id
sequence
operation_type
intent
effect
result
status
created_at
effect_started_at
effect_completed_at
result_recorded_at
evidence_refs
artifact_refs
```

必要に応じて、tool_id、provider_id、agent_id等をReferenceとして保持できる。

Intent / Effect / Resultは構造化可能なSchemaを持つ。
巨大stdout等は直接埋め込まない。

---

# 15. Operation Status

最低限次の状態を持つ。

```text
pending
executing
succeeded
failed
indeterminate
```

`indeterminate`は、Effectが発生した可能性はあるが成功・失敗を断定できない状態を表す。

将来のCrash Recovery / Resumeで重要な状態となる。

---

# 16. Execution Workspace

Attemptがどの実行環境で動いたかを記録する。

最低限、Repository、Worktree、Base Commitを追跡する。

これにより「そのAttempt / OperationはどのRepository状態に対して実行されたか」を後から特定できる。

---

# 17. QA Ledger

QA EntryはWork Itemに紐付け、State Storeへ保存する。
Conversationだけに存在するQAは作らない。

既に合意したQA状態の候補:

```text
open
resolved_by_evidence
answered_by_human
accepted_assumption
superseded
```

具体SchemaはQA Ledger設計で確定する。

---

# 18. Human Decision

Human Decisionは構造化してState Storeへ保存する。

```text
Decision Requested
↓
Human Answered
↓
Requirement / State Update
```

Conversation Logだけを根拠にしない。

---

# 19. Gate

GateもState Storeで管理する。

Gateは単なる`status = passed`だけではなく、Current State、Evaluation History、Approval、Policy Evaluation、Artifact Revision References、Evidence Referencesを保持できる構造とする。

「なぜGateがPASSしたのか」を後から再現できることを目的とする。

---

# 20. Artifact / Artifact Revision

Artifact IdentityとRevisionを分離する。

```text
Artifact
├ Revision 1
├ Revision 2
└ Revision 3
```

GateやEvidenceはArtifact名だけでなく、特定Artifact Revisionを参照する。

---

# 21. Artifact / Evidenceの実体

大容量PayloadをState DBへ直接保存しない。

例:

- XLSX
- DOCX
- Screenshot
- 画像
- 巨大Diff
- Test Report
- 巨大stdout
- Coverage HTML

DB側には、ID、Revision、Locator、Digest、Size、MIME Type、Metadata、Reference等を保存する。

---

# 22. AI-DE Local Object Store

AI-DE自身が生成・取得したEvidence Payload等について、Project単位のLocal Object Storeを持つ。

概念例:

```text
<project-state-dir>/
├ state.sqlite
└ objects/
   ├ ab/
   │  └ <digest>
   └ ...
```

Content Addressed Storage方式を採用する。
SHA-256等のDigestをObject Identityとして利用する。

Repository内Project ArtifactそのものをすべてObject Storeへコピーして正本化するわけではない。
Repositoryや将来のDocument System等が正本なら、locator、revision、digestを記録する。

Local Object Storeは将来、S3 / MinIO / Enterprise Storage等へAdapterで差し替え可能にする。

---

# 23. Retention

Phase 1では、構造化履歴を原則削除しない。

保持対象:

- Operation Log
- Human Decision
- Gate Evaluation
- Artifact Revision Metadata
- Evidence Metadata
- Invariant Violation
- Command Receipt

大容量PayloadもPhase 1では基本保持する。

将来、Active → Archived等のLifecycleを追加可能にする。
初期段階から自動削除は行わない。

---

# 24. Transaction Boundary

外部EffectをDB Transaction内部へ無理に閉じ込めない。

## Transaction 1

```text
Operation作成
Intent保存
status = pending
COMMIT
```

## External Effect

```text
Tool / Command / API等を実行
```

## Transaction 2

```text
Effect保存
Result保存
Evidence登録
Operation Status更新
Attempt / Task State更新
Event Outbox登録
COMMIT
```

Effect後にCrashした場合、Intentあり / Resultなしという状態から`indeterminate`を判断できる。

この構造により、Intent → Effect → Result → EvidenceをState Store上で実現する。

---

# 25. Transactional Outbox

Protocol EventはSSOTではない。

ただし、State変更と「このEventを通知する」を同一Transaction内に記録するTransactional Outbox Patternを採用する。

```text
DB Transaction
├ State Change
└ Outbox Entry
        ↓ COMMIT

Protocol Host
        ↓
Outboxを読み取る
        ↓
OrcaへEvent通知
```

Event送信直前にProcessがCrashしても、再起動後にOutboxから通知処理を継続できる。

現在状態の正本はあくまでState Storeである。
OrcaがEventを取り逃した場合はSnapshotを再生成して復元する。

---

# 26. Snapshot

Snapshot自体はSSOTとして保存しない。
必要になった時点でState Storeから組み立てる。

```text
State Store
↓
Snapshot Builder
↓
Orca / CLI
```

これにより二重管理を避ける。

---

# 27. Revision

Mutable EntityにはRevisionを持たせる。

Protocol Clientが`expected_revision`でCommandを送った時、現在Revisionが異なれば`REVISION_CONFLICT`として拒否する。

古いClient Stateからの操作を防止する。

---

# 28. command_id / Command Receipt

状態変更Commandには`command_id`を付与する。
State StoreへCommand Receiptを記録する。

例:

```text
command_id
method
target
request_hash
status
result_ref
processed_at
```

同じCommandが通信障害等で再送されても、二重実行を行わない。

---

# 29. Concurrency

Agent / WorkerはState DBへ直接アクセスしない。

```text
Agent / Worker
      ↓
AI-DE Runtime
      ↓
State Store Service
      ↓
SQLite / PostgreSQL
```

SQLiteでは最低限、WAL mode、foreign_keys = ON、busy_timeout、short transactionを使用する。

---

# 30. Active AI-DE Host

**1 ProjectにつきActive AI-DE Hostは常に1つだけとする。**

Phase 1限定の制約ではない。

```text
Orca Client A ─┐
Orca Client B ─┼→ AI-DE Host → State Store
Agents         ─┘
```

ClientやAgentは複数でもよい。
State Authorityを持つHostは1つだけ。

---

# 31. Host Lock

共通概念として`ProjectHostLock`を持つ。

Backendに応じて実装を変える。

## SQLite

OS File Lockを使用する。
単なるPIDファイルだけをAuthorityにはしない。

Lock Fileに診断情報としてpid、started_at、socket_path、host_version等を記録してよい。

## PostgreSQL

PostgreSQL Advisory Lockを利用する。
Connection喪失時にLockが解放される方式を利用する。

---

# 32. Schema Migration

State Storeは`schema_version`を持つ。

AI-DE起動時にSchema Versionを確認し、必要に応じてMigrationする。

安全な追加Migrationは自動化可能。
破壊的MigrationはBackup / Validation等を伴う。

---

# 33. SQLite / PostgreSQL共通Interface

AI-DE Core内へDB固有SQLを散らさない。

```text
AI-DE Core
↓
State Store Interface
↓
SQLite Adapter / PostgreSQL Adapter
```

Business LogicはAI-DE Core側に持つ。
DB TriggerだけにBusiness State Transitionを依存しない。

---

# 34. State Machine

各EntityのState TransitionはAI-DE Coreで明示的なState Machineとして定義する。

DBはForeign Key、Unique、NOT NULL、Check Constraint等による構造的な最終防衛線を担当する。

正式なPhase / Task / Attempt / Gate等の状態一覧と遷移条件はPhase Gate設計と合わせて確定する。

Platform Testは同じState Machineを直接検証する。

---

# 35. PostgreSQL Credential

Project設定へPasswordを直接保存しない。

例:

```yaml
state_store:
  backend: postgresql
  connection_ref: env:AIDE_STATE_DATABASE_URL
```

CredentialはEnvironment Variable、OS Secret Store、将来のCredential Broker等から取得する。

Git管理されるProject ConfigへDB Passwordを保存しない。
Security ProxyはLLM通信Securityの責務であり、DB Credential管理をSecurity Proxyへ押し込まない。

---

# 36. PostgreSQL内のProject分離

1 Project = 1 Databaseを必須にはしない。

1つのPostgreSQL環境内で複数Projectを`project_id`により管理可能とする。

厳格な隔離が必要な環境ではDedicated Databaseを選択可能にする。

Shared / Dedicatedの違いでAI-DE Core Modelは変更しない。

---

# 37. SQLite → PostgreSQL Migration

Dual Writeは行わない。

Migration時はState Authorityを1つに保つ。

```text
AI-DE Project停止
↓
SQLiteをFreeze
↓
Consistent Snapshot
↓
PostgreSQLへImport
↓
件数 / Relation / Digest等を検証
↓
Backend設定変更
↓
AI-DE Host再起動
```

SQLiteとPostgreSQLへの同時Writeは禁止。
将来、専用Migration Commandを提供可能とする。

---

# 38. State Store障害時

基本方針は **Fail Closed**。

State Storeへ必要な記録を書けない状態で、新しい外部Effectを継続しない。

```text
Intentを保存できない
↓
External Effect実行禁止
```

State StoreがRead可能であれば、Orcaで状態確認、診断、Recovery操作等のRead-only利用は許可できる。

ただし新しいWrite / External Effectは停止する。

Effect後にStore障害が起きた場合は、復旧後にResult未確定Operationとして扱い、`indeterminate`等を利用してRecovery対象にする。

---

# 39. State Store長期故障への追加要求

基本はFail Closedとするが、State Store障害が長時間続くことでProject進行が不必要に停止することも問題である。

そのため、

**State AuthorityやEvidenceを壊さずに、State Store故障から迅速に復旧する仕組みを持つこと**

を追加要求とする。

ただし具体方式は現時点では未決。

今後、少なくとも次を検討する。

- SQLite自動Backup
- Point-in-Time / Snapshot Recovery
- PostgreSQL Backup / Restore
- Store Health Check
- 起動前Integrity Check
- 自動Recovery可能範囲
- Corruption検知
- Read-only Degraded Mode
- Emergency Restore
- Object StoreとのConsistency確認
- Migration途中失敗からのRollback / Recovery
- Recovery後のOperation `indeterminate`検出
- どの障害で人間判断が必要か
- RPO / RTOの扱い

重要:

**故障中に別の非Authority Storeへ勝手にFailoverして開発を継続する方式は、State Authorityが二重化する可能性があるため、現時点では採用しない。**

Recovery方式は別途設計する。

---

# 40. Platform Testとの関係

State StoreはAI-DE Platform Testの重要な検証対象。

```text
Deterministic Boundary
↓
Fault Injection
↓
State Store確認
```

検証例:

```text
Effect直後にCrash
↓
Operation = indeterminate
Attempt = interrupted等
Gate = 不正に進行していない
```

State Store、Runtime Invariant、Deterministic Boundary、Fault Injectionを組み合わせ、
「AI-DEが正常時だけでなく異常時にも正しいStateを維持する」ことを検証する。

---

# 41. 現時点で残っている詳細設計

State Storeの基本設計は合意済み。

主に次の具体仕様が残る。

1. 正式なTable / Column Schema
2. Project discovery方法
3. Phase / Task / Attempt / Gate等の正式State Machine
4. Operation Intent / Effect / Resultの詳細Schema
5. Local Object Store Adapter Interface
6. Transactional Outboxの詳細Schema / Delivery管理
7. SQLite / PostgreSQL Adapter Interface
8. PostgreSQL Shared / Dedicated DBの具体Configuration
9. Schema MigrationのVersioning規約
10. SQLite → PostgreSQL Migration Tool仕様
11. State Store Backup / Recovery / Corruption対策
12. 長期障害時のRPO / RTO / Recovery Policy

特に次に設計すべき大きな論点は、

- State Store障害時のRecovery設計
- Phase Gate共通モデル + State Machine

である。
