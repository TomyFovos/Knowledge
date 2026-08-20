# Enterprise Knowledge Graph Architecture

## 概要

Knowledge GraphをPoCから業務基盤へ広げると、難しさはグラフ検索そのものから、Schema、権限、更新、外部システム統合へ移る。

エンタープライズKGは「Neo4jを置く」ことではなく、**組織の事実・関係・履歴を継続的に正しく保ち、それを安全に問い合わせられる仕組み**として設計する必要がある。

## 主要な設計課題

元資料が挙げる中心課題は次の四つである。

- 業務概念をどうNode / Edgeへ落とすか
- 誰がどのNode・Propertyを参照・操作できるか
- 日々変わる業務データをどう反映し続けるか
- CRM、ERP、Ticket、Documentなど異なるSourceをどう統合するか

これらは互いに独立していない。たとえば権限を後付けすると、SchemaとQuery層の両方を見直すことになる。

## 現在状態と履歴を分ける

元資料はEvent Sourcingとの組み合わせを一つのパターンとして示している。

```text
Business Event
    ↓
Event Store / Queue
    ↓
KG Updater
    ├─ Current snapshot
    └─ Change/Event history
```

KGに現在状態だけでなくChangeEventをNodeとして残せば、

- 現在どうなっているか
- 誰が、いつ、何を変えたか

を同じ構造から追える。

ただし全イベントを無条件にKGへ保持する必要はない。後から関係探索・監査に使う情報を選ぶ。

## Schema Evolution

KGのSchemaも業務とともに変わる。

変更を場当たり的に行わず、SchemaVersionやMigrationを明示して管理する。元資料では、破壊的変更よりも後方互換性を持つ追加を基本とし、旧Propertyと新Propertyを一定期間併存させるダブルライトのような移行を安全策として挙げている。

KGはRDBより柔軟でも、Schema管理が不要になるわけではない。

## AuthorizationをGraphの外側だけに置かない

エンタープライズKGでは「UserがどのScopeへアクセスできるか」自体も関係として表現できる。

```text
User --MEMBER_OF----> Department
User --HAS_ACCESS_TO-> Project
Project --CONTAINS--> Customer
```

この構造を辿れば、ユーザーの所属やScopeからアクセス可能な対象を動的に計算できる。

元資料ではNode-level securityやABAC相当の考え方を示しているが、同時に、概念的なQuery Wrapperだけで本番認可を実装するのは危険であり、Neo4j EnterpriseのRBACや専用認可層を使うべきだと注意している。

つまり、**権限関係をKGで表現すること**と、**DBレベルで安全に強制すること**は別の責任である。

## 継続的更新

KGは古くなれば価値を失う。

本番では、CRMのWebhook、ERPのCDC、Ticket systemのEventなどをEvent Hubへ集め、KG consumerが `MERGE` / UpdateするEvent-driven構成が候補になる。

```text
CRM ─┐
ERP ─┼─> Event Hub ─> KG Consumer ─> Knowledge Graph
Ticket┘
```

一方、小規模な段階から必ずリアルタイム同期にする必要はない。更新頻度は業務要件から決める。

## MCPとの位置関係

MCPはLLMが外部ToolへアクセスするためのI/O境界として使える。KGをMCP Serverとして公開すれば、AgentやLLM Clientから共通Toolとして検索・Traversalを呼び出せる。

ただしMCPはKGの代わりではない。

- MCP: 接続・Tool invocation
- KG: 永続的なEntity / Relation / Memory

という役割の違いがある。

## 本番設計で見るべきもの

KGのQuery性能だけを監視しても十分ではない。

少なくとも、

- データ更新遅延
- Entity重複・欠損
- Schema migration
- 権限逸脱
- 生成Cypherの安全性
- Backup / Restore
- Query latency
- AgentによるRead / Write履歴

まで含めて運用対象になる。

## 関連

- [[Knowledge Graph Modeling and Construction]]
- [[Formal Layer Sandwich for Enterprise AI]]
- [[Knowledge Graph for AI Agents]]
- [[Knowledge Graph Adoption and Operations]]

## 参考資料

- DevRev-JP, 「LLMをもっと賢くする：ナレッジグラフ実践入門」
- https://github.com/DevRev-JP/tech-blog/tree/main/books/knowledge-graph-llm-guide
- 主に `enterprise-kg-architecture.md` を整理。