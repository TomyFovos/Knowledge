# Knowledge Graph Adoption and Operations

## 概要

Knowledge Graph導入で難しいのは、グラフDBを動かすことより、**どの知識を最初に入れ、誰が更新し、どう組織へ広げるか**を決めることである。

元資料は、全社KGを最初から作るのではなく、小さいユースケースから価値を確認し、更新・権限・本番運用を段階的に追加する方針を取る。

## 導入でぶつかる現実的な壁

### データ統合

CRM、ERP、Ticket、Wiki、Documentなど、データは異なる形式・Schema・Ownerに分散している。

実務ではKG本体より、抽出・正規化・Entity Resolution・ETLに大きな工数がかかる。元資料も「Garbage in, garbage out」を強調し、まずデータ取得方法を棚卸しする必要があるとしている。

### Data Ownership

複数部門の情報を統合すると、「誰のデータか」「誰が共有を許可するか」という問題が生じる。

KG導入は技術プロジェクトだけではなく、Data Governanceを伴う。最終責任者やSponsorが曖昧なまま全社横断で進めると、調整で停止しやすい。

### 継続的更新

KGは作った時点では正しくても、業務が変わればすぐ古くなる。

最初からRealtime同期を要求せず、手動更新・週次Batchから始め、価値と鮮度要件が明確になったところでWebhookやEvent-driven updateへ進む。

### 権限

KGはRelationを辿ることで想定外の情報へ到達できるため、Access Controlを後付けしにくい。

小規模でも「誰が何を読めるか」は最初からSchema設計の一部として考える。

## Small Start

元資料は最初から全社の知識を統合するやり方を避ける。

最初のPoCは、

- 1 use case
- 1〜2 data sources
- 3〜5 representative questions
- read-only中心

程度まで絞る。

適した例は、BugとComponentと担当Engineerの関係、FAQとProduct Documentの関係、Product互換性など、関係を辿る価値が目に見える領域である。

## 世界の導入事例から見る共通点

元資料は金融、製薬、Healthcare、製造、通信などの事例を挙げている。

分野は異なっても、KGが使われる場面には共通点がある。

- 多段の関係探索が必要
- Entity間のNetwork自体が意味を持つ
- Data sourceが複数に分かれる
- 説明可能性やTraceabilityが必要

不正検知、創薬、Supply Chain、Network inventoryなどは、単一RecordではなくRelationの集合から答えを出す典型例である。

個々の企業効果の数値は元資料が各Customer Story等から紹介したものであり、本ノートでは一般的な効果量として扱わない。

## LocalからProductionへ段階的に進める

元資料の最小構成は、

```text
Neo4j + Ollama + LangChain
```

である。

段階は概ね次のように整理できる。

### Phase 1: Local / PoC

Docker ComposeでNeo4jとLLMを動かし、Schema・Query・代表Questionを磨く。

### Phase 2: VPS / Cloud VM

実利用が始まったら、Password、Firewall、Backup、監視を追加して単一Hostで本番化する。

### Phase 3: HA / Enterprise

停止が直接損失につながる、細かいRBACが必要、複数部署が共有する、といった要件が出た時点でNeo4j EnterpriseやManaged Serviceを検討する。

大規模Orchestrationを最初から導入するのではなく、要件が生まれた順にInfrastructureを増やす。

## OSSかManaged Serviceか

OSSはLicense costを抑えられるが、Schema、ETL、認可、Backup、Monitoring、Upgradeを自分たちで持つ必要がある。

Managed ServiceやEnterprise Editionは、HA、RBAC、Supportなどの運用負担を外部化できる。

判断軸は「無料か有料か」ではなく、

- 停止許容時間
- 権限要件
- 運用できるEngineer数
- Data量 / Query量
- Support契約の必要性

で決める。

## KGを育てる

KGは完成品として一度作るより、利用されるたびにSchemaとRelationを改善する方が現実的である。

運用時には、

- どのQueryが使われたか
- 答えられなかったQuestionは何か
- どのEntityが重複・欠損したか
- どのRelationが更新されなくなったか

を見て、次のModel変更へ戻す。

```text
Use → Observe → Fix data/model → Add use case → Use
```

この循環が止まると、KGは「作ったが誰も信用しないデータベース」になる。

## 関連

- [[Knowledge Graph Modeling and Construction]]
- [[Enterprise Knowledge Graph Architecture]]
- [[Knowledge Graph for AI Agents]]
- [[Knowledge Graph for LLM]]

## 参考資料

- DevRev-JP, 「LLMをもっと賢くする：ナレッジグラフ実践入門」
- https://github.com/DevRev-JP/tech-blog/tree/main/books/knowledge-graph-llm-guide
- 主に `world-kg-use-cases.md` と `commercial-implementation.md` を整理。