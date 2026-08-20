# Knowledge Graph Modeling and Construction

## 概要

Knowledge Graphの構築で最初に決めるべきなのは、データベース製品ではなく **何のために作るか** である。

元資料は「社内のすべての知識をグラフ化する」ような広すぎる目標を避け、最初は一つの利用者像と少数の代表質問に絞ることを勧めている。

## 最初にスコープを決める

最初のKGについて、次の四つを明確にする。

1. 誰が使うか
2. 何を知りたいか。代表質問を3〜5個程度にする
3. どのデータソースが既にあるか
4. どの頻度で更新が必要か

元資料の目安は **1 persona / 5〜10 query / 1〜2 data source** から始めること。

スコープを広げすぎると、EntityとRelationの組み合わせが増え、データ品質と更新フローの維持が難しくなる。

## RDFかProperty Graphか

### RDF

`Subject - Predicate - Object` のトリプルを基礎とする。W3C標準やLinked Dataとの相互運用を重視する場合に向く。

### Property Graph

NodeとEdgeにPropertyを持たせる。Neo4jとCypherのような開発者向けエコシステムがあり、柔軟なモデリングと探索を行いやすい。

元資料では、標準準拠や外部Linked Dataとの接続が主要要件でなければ、Property Graphから始める選択を推している。

## 構築フロー

```text
Use Case
   ↓
Entity definition
   ↓
Schema / Relation design
   ↓
Data ingestion
   ↓
Representative queries
   ↓
Model revision
   ↓
LLM integration
```

LLM連携を先に作るのではなく、まずKG単体で代表質問に正しく答えられるかを確認する。

## EntityとPropertyの分け方

ある情報をNodeにするかPropertyにするかは、後からどんな関係を辿りたいかで決める。

Node化を検討する条件は、

- 他のEntityと複数のRelationを持つ
- 独立して参照・更新される
- それ自体を起点・終点に問い合わせたい

という場合である。

単純な属性値で、他のEntityとの関係を持たず、単独で問い合わせる必要がないものはPropertyに向く。

### Property肥大化を避ける

担当者名、Component名、関連Document名をすべてBugのPropertyとして保存すると、関係探索や更新で文字列検索が必要になる。

```text
Bug --ASSIGNED_TO--> Engineer
Bug --AFFECTS------> Component
Component --DOCUMENTED_BY--> Document
```

のように独立Entityとして分ければ、一つのEntityの変更を他のNodeへ複製せずに済む。

## Relationを設計の中心に置く

KGの価値はNode数ではなく、何をRelationとして明示したかで大きく変わる。

代表質問から「どの経路を辿れば答えに着くか」を逆算し、Relationを設計する。

単にデータをグラフDBへコピーしても、意味のあるRelationがなければKGとしての価値は低い。

## データ投入とEntity Resolution

実務ではCSV、CRM、Ticket、Wiki、Documentなど複数ソースからデータを取り込む。

ここで難しいのは、同じ実体が異なる名前・IDで存在することである。表記揺れを放置すると一つの人物や製品が複数Nodeへ分裂する。

そのため、外部ID、正規化した名称、対応表などを使い、一意性を設計段階から持たせる必要がある。

## 最初から完璧なSchemaを狙わない

Property GraphではSchema変更を比較的柔軟に行える。元資料は、少数のNode type / Edge typeから始め、代表Queryを実行しながらモデルを改善するアプローチを取る。

重要なのは「全部の業務概念を最初に表現すること」ではなく、**選んだユースケースへ正しく答えられる最小構造を作ること**である。

## 最小実装

元資料の主要実装スタックは、

- Neo4j
- Ollama
- LangChain

である。

ローカル環境でNeo4jを起動し、小さなデータを投入してCypherで期待する結果が得られることを確認した後、自然言語からの問い合わせを追加する。

## 関連

- [[Knowledge Graph]]
- [[Hybrid RAG and Knowledge Graph]]
- [[Enterprise Knowledge Graph Architecture]]
- [[Knowledge Graph Adoption and Operations]]

## 参考資料

- DevRev-JP, 「LLMをもっと賢くする：ナレッジグラフ実践入門」
- https://github.com/DevRev-JP/tech-blog/tree/main/books/knowledge-graph-llm-guide
- 主に `how-to-build-kg.md` を整理。