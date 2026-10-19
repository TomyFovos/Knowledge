---
type: Pattern
status: Researching
topics: [AI-DE, State Store, 永続化, 障害回復]
created: "2026-10-19"
updated: "2026-10-19"
follow_up: true
follow_up_type: research
---

# AI-DEのState Storeと障害回復

State Storeは、AI-DEの現在状態、履歴・監査、Artifact / Evidence参照を保持するRuntime Stateの正本である。Orcaの画面、Task Tracker、会話、Protocol Event、画面表示用Snapshotを正本にしない。

以下は2026-08-27の基本設計合意を記録した提供資料の整理であり、実装済み機能の一覧ではない。

## Projectと正本を一意に保つ

- ProjectはAI-DEが発行する不変IDを持つ。Repository Path、Git URL、Issue番号をIdentityにしない。
- 一つのProjectに複数Repositoryを関連付けられ、物理配置を強制しない。
- 標準BackendはSQLite、PostgreSQLは明示設定で選ぶ。一つのProjectに正本Backendは一つだけ。
- SQLiteとruntime情報はRepository / worktree外のProject別State Directoryに置く。
- 一つのProjectでActive AI-DE Hostは常に一つ。複数Client / Agentは許せても、状態を決定するHostを複数にしない。

SQLiteではOSファイルロック、PostgreSQLではadvisory lockを使う方針。PIDファイルだけを権限の根拠にしない。

## 実行を仕事・試行・作用へ分ける

```text
Project → Work Item → Phase → Task → Attempt → Operation
                            Gate        ↓
                                    Execution Workspace
Artifact → Artifact Revision ← Evidence・Gateの参照
```

Taskは仕事そのもの、Attemptは一度の実行、OperationはAttempt内の具体的な作用である。ModelやAgentを変えて再試行してもTask Identityは維持する。どのRepository・worktree・base commitで実行したかも記録する。

OperationはIntent / Effect / Resultと時刻、状態、Evidence・Artifact参照を構造化する。`indeterminate`は、作用が起きた可能性はあるが成否を断定できない状態を表す。

## 外部作用をDB Transactionの外で扱う

```text
Transaction 1：Operation・Intentを保存してCOMMIT
    ↓
外部Effect：ツール・コマンド・APIを実行
    ↓
Transaction 2：Result・Evidence・状態変更・Outboxを保存してCOMMIT
```

Effect直後にクラッシュするとIntentあり / Resultなしになる。これを成功や未実行と決めつけず、Recovery対象として追跡する。

状態変更とOutbox登録は同一Transactionにし、通知の送信失敗と状態の記録を分離する。Protocol Eventを取り逃したClientはState StoreからSnapshotを再構築する。会話や表示用Snapshotを別の正本として永続化しない。

## 同時実行と保存形式

| 仕組み | 目的 |
|---|---|
| Relational Core + JSON Extension | 重要Entity・Relationは制約で守り、Provider固有拡張等だけJSONへ |
| `expected_revision` | 古いClient状態からの更新を拒否 |
| `command_id` / Command Receipt | 再送時の二重処理を防ぐための受領記録 |
| State Store Service | Worker / AgentのDB直接アクセスを避ける |
| Coreの明示的State Machine | 状態遷移をDB固有Triggerだけへ依存させない |

SQLiteはWAL、外部キー、busy timeout、短いTransactionを使う方針。DB固有SQLはAdapterへ閉じ込める。

大きなXLSX、画像、stdout、テストレポートはDBへ直接埋めず、locator・revision・digest等を保存する。AI-DE自身が得たPayloadはcontent-addressedなLocal Object Storeを使い、Git等が正本の成果物まで無条件にコピーして正本化しない。

## 障害・移行・未決事項

必要なIntentを書けない場合は新しい外部Effectを開始しない。Storeが読めるなら診断用のread-only利用を検討できるが、故障中に別の非正本Storeへ切り替えて進行する案は採用されていない。

SQLite→PostgreSQL移行は、停止、Freeze、整合Snapshot、Import、関係・件数・digest検証、設定切り替え、再起動という方針で、Dual Writeはしない。

Schema、正式State Machine、Outbox配信管理、Adapter、Migration Tool、Backup / Restore、破損検出、RPO / RTO等は詳細設計が残る。「基本設計合意」と「復旧方式まで完成」を区別する。Platform TestではEffect直後のクラッシュなどを注入し、不正なGate進行がないことを検証する構想である。

## 関連・参考資料

- [[AI-DEの指示生成と実行時統制]]
- [[AI-DEの構成と責務を読むための機能マップ]]
- [[システム境界と回復可能性]]
- 全文：[[Sources/Mixed Memos 20261019/Markdown/AI-DE State Storeの設計決定事項（2026年8月27日）]]

