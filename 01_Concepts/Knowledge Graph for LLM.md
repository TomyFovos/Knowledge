# Knowledge Graph for LLM

## 概要

LLMを業務へ持ち込むと、「文章は自然なのに、事実として信用しきれない」という問題が現れる。

Knowledge Graphはその問題を一人で解決する万能技術ではない。RAG、Database、Rule Engine、Agent Toolingなどと役割を分け、**LLMの外側に、更新可能で追跡可能な知識構造を置く**ための一つの基盤である。

本ノートは、DevRev-JPの「LLMをもっと賢くする：ナレッジグラフ実践入門」から分解したナレッジの入口である。

## 全体像

```text
                         ┌─ RAG ───────── 文書・背景・手順
User / Agent ─ Router ──┼─ Knowledge Graph ─ 関係・集合・経路
                         ├─ SQL / DB ───── 正確な値
                         └─ Rule Engine ── 権限・Policy
                                   ↓
                                  LLM
                                   ↓
                          Explanation / Action
```

重要なのは、「LLMに知識を全部覚えさせる」ことではない。

- 非構造化文書はRAG
- Entity間のRelationはKG
- Transactionalな値はRDB
- Policy判断はRule Engine
- 自然言語理解・生成はLLM

のように、問題の種類を分ける。

## ナレッジマップ

### 基礎

[[Knowledge Graph]]

Node / Edge、RDF、Property Graph、RDB・Vector DBとの違いを整理する。

### なぜRAGだけでは足りないのか

[[RAG Limitations and Knowledge Graph]]

Chunk boundary、Cross-document reasoning、否定Query、集計など、Vector RAGが構造的に苦手な問いを整理する。

### RAGとKGをどう組み合わせるか

[[Hybrid RAG and Knowledge Graph]]

質問を `rag / kg / hybrid` にRoutingし、文脈検索と構造Queryを統合するPattern。

### KGをどう作るか

[[Knowledge Graph Modeling and Construction]]

Use caseの絞り込み、Entity / Property設計、Relation設計、RDF vs Property Graph、データ投入の考え方を整理する。

### LLMを形式レイヤで挟む

[[Formal Layer Sandwich for Enterprise AI]]

LLMへ事実取得・権限判断まで任せず、SQL / KG / Rule Engineなどの決定論的Layerを前後に配置するPattern。

### 本番のKG基盤

[[Enterprise Knowledge Graph Architecture]]

Schema evolution、Event-driven update、履歴、Authorization、MCPとの役割分担など、KGを継続運用するArchitecture。

### AI AgentとKG

[[Knowledge Graph for AI Agents]]

AgentのRead / Write / Reason、Long-term Memory、Permission-aware KG、HITL、Prompt Injection対策を整理する。

### 導入・運用

[[Knowledge Graph Adoption and Operations]]

Small Start、ETL、Data Ownership、世界のUse Case、LocalからProductionへの段階的移行を整理する。

## この資料から得られる中心的な考え方

Knowledge Graphの価値は「グラフDBを使うこと」ではない。

**LLMだけでは曖昧になる知識・関係・権限・履歴を、外から検査可能な構造として持つこと**にある。

しかし、すべてをKGへ入れる必要もない。文章的な背景はRAGの方が自然で、正確な数値やTransactionはRDBの方が適している。

したがって設計の問いは、

> 「KGを使うか？」

ではなく、

> 「この情報・判断は、どの形式で持つと最も検査可能で更新可能か？」

になる。

## 出典上の注意

元資料には著者独自の整理・推奨も含まれる。

たとえばAI AgentのL1〜L5分類は標準規格ではなく、本書が説明のために置いた分類である。また導入効果やCostの数値には、Customer Storyからの引用や著者推測が含まれる。

そのため、本Knowledge Baseでは概念・設計Patternを中心に抽出し、個別の数値を普遍的な事実として一般化しない。

## 参考資料

- DevRev-JP, 「LLMをもっと賢くする：ナレッジグラフ実践入門」
- https://github.com/DevRev-JP/tech-blog/tree/main/books/knowledge-graph-llm-guide
- 元資料の章構成: Introduction / Knowledge Graph / RAG limitations / Use cases / Build / Beyond RAG / Enterprise / AI Agents / Implementation