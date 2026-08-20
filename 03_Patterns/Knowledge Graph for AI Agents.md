# Knowledge Graph for AI Agents

## 概要

AI Agentが自律性を増すほど、「何を知っているか」だけでなく、**何をしてよいか、誰に影響するか、何を記録すべきか**を扱う必要がある。

元資料では、Knowledge GraphをAgentの知識源だけでなく、権限・業務文脈・履歴・長期記憶を結ぶ基盤として位置づけている。

## L1〜L5という整理

元資料は便宜的な分類としてAgentをL1〜L5へ分ける。これはSAEなどの標準分類ではない。

- L1: 検索・回答
- L2: 複数Taskを順序立てて実行
- L3: 特定Platform内で自律実行し、重要判断ではHITL
- L4: Tool / Workflow内で人間確認なしに完結
- L5: 複数System・Departmentをまたいで自律実行

重要なのは番号ではなく、L2からL3以降へ進むと「提案」から「実行」へ責任が変わることである。

## HITL境界

Agentが提案するだけなら、最終責任を人間が持ちやすい。

Agent自身が実行するなら、

- この操作は許可されているか
- 影響範囲はどこまでか
- 誰の承認が必要か
- 失敗したときにどこまで戻せるか

を事前に判断する仕組みが必要になる。

元資料は、組織構造・権限Policy・Workflow・業務Dataの関係をKGへ持たせる **権限認識型KG** をその基盤としている。

## AgentがKGを使う三つの基本パターン

### Read

Task実行前にKGから必要なContextを取得する。

例:

- CustomerのPlan
- 担当Team
- SLA
- 関連Document
- 過去Incident

LLMの記憶に依存せず、現在の構造化された状態を参照する。

### Write

Agentが行った操作・判断・影響対象をKGへ記録する。

```text
Agent --PERFORMED--> AgentAction --AFFECTED--> Entity
```

これにより後からAuditでき、他Agentが過去のActionを次の判断へ使える。

ただし、全Tool callを無条件でKGへ保存すると肥大化する。「後から誰かが参照する意味がある情報」を選ぶ必要がある。

### Reason

Graph traversalやRelationを使い、判断根拠そのものを構造化Queryとして表現する。

例えばEscalation条件を、Customer Plan、直近Ticket数、障害の影響CustomerといったRelationから算出する。

この方式では、最終判断をLLMの内部推論だけに置かず、**なぜその条件が成立したかをQueryで追える**。

## KGをAgent Toolとして公開する

AgentからKGを利用するには、自由なDBアクセスを与えるより、目的別Toolとして公開する方が安全である。

```text
search_customer_info(name)
get_related_incidents(service)
kg_traverse(start, relation, max_hops)
```

Toolの入力・出力を限定すると、Agentが実行できるQuery範囲も制御しやすい。

元資料ではLangChain Tool、Function Calling、MCP ServerとしてKGを公開する例を示している。

## Agent MemoryとしてのKG

元資料はAgent MemoryをShort-term / Long-termへ分ける。

- Short-term: 現在Sessionの会話・一時Context。Memory / Redis等
- Long-term: Sessionを越えて残すKnowledge。KG

Session終了時に重要情報を抽出し、User、Decision、Preference、Past ActionなどとのRelationを付けてKGへ保持することで、単なる全文会話ログより構造的に再利用できる。

重要なのは「全部覚えること」ではなく、後から何と結び付けて検索・推論したいかを決めることである。

## Writeには権限と承認を付ける

Read-only KGと違い、AgentがKGを書き換えると、後続Agentの判断そのものへ影響する。

したがってWriteでは、

```text
Agent proposes KG change
       ↓
Scope / Permission check
       ↓
Risk evaluation
       ↓
Human approval when threshold exceeded
       ↓
Write + Audit
```

という流れを取る。

元資料は、人間承認をすべてのWriteへ付けるのではなく、「大量Nodeへ影響する」「Deleteを含む」「重要Customerへ影響する」など、Risk条件を超えた操作へ限定する例を示している。

## Prompt Injectionと最小権限

Agentへ自然言語から自由にCypherを生成させる場合、Prompt Injectionや意図しないData accessが問題になる。

元資料の対策方針は、

- User inputをそのままQueryへ埋めない
- 生成Cypherを実行前に検証する
- Read-only user / allowlistを使う
- Agentへ必要最小限のKG Scopeだけを与える

というDefense in Depthである。

単純なKeyword sanitizeだけで完全防御できるとはしておらず、本番では専門的なSecurity reviewが必要と明記している。

## 関連

- [[Formal Layer Sandwich for Enterprise AI]]
- [[Enterprise Knowledge Graph Architecture]]
- [[Dynamic Component Lifecycle]]
- [[Spatiotemporal Composability]]

## 参考資料

- DevRev-JP, 「LLMをもっと賢くする：ナレッジグラフ実践入門」
- https://github.com/DevRev-JP/tech-blog/tree/main/books/knowledge-graph-llm-guide
- 主に `kg-and-ai-agents.md` を整理。