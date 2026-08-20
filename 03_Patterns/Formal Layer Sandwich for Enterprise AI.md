# Formal Layer Sandwich for Enterprise AI

## 概要

業務AIで問題になるのは、LLMが文章を生成することではなく、**LLMに事実取得や業務判断まで任せてしまうこと**である。

元資料では、LLMの前後へ決定論的な処理を配置する考え方を **形式レイヤ** と呼び、LLMを形式レイヤで挟む「サンドイッチ構成」として説明している。

## 形式レイヤとは

同じ入力に対して同じ結果を返す、明示的な規則・データ問い合わせの層を指す。

元資料では主に三種類を挙げている。

| 形式レイヤ | 主な役割 |
| --- | --- |
| SQL / Database | 金額・数量・日付などの正確な値を取得する |
| Knowledge Graph | Entity間の意味・関係を探索する |
| Rule Engine | 権限・承認・コンプライアンスなどのルールを判定する |

LLMはこれらと違い、確率的な推論・文章生成を担う。

## Sandwich Architecture

```text
User Request
    ↓
Input validation
    ↓
SQL / KG / deterministic retrieval
    ↓
LLM reasoning / generation
    ↓
Rule / policy validation
    ↓
Validated response or action
```

重要なのは、LLMの前後に何かを置くこと自体ではない。

**どの責任をLLMから外すか** が設計の中心になる。

- 正確な数値取得 → Database
- 関係探索 → KG
- 許可・禁止の判定 → Rule / Policy layer
- 曖昧な自然言語理解・説明 → LLM

## なぜ有効か

LLMへ「会社のルールを覚えさせる」だけでは、同じ規則が毎回同じように適用される保証がない。

形式レイヤへルールや事実を移すことで、LLMはそれらを発明・再現する責任から離れられる。

この構成では、LLMは業務ルールそのものではなく、**決定論的な結果を人間が理解できる言葉へ変換する役割**に寄せられる。

## MCPとKG

元資料ではMCPを外部ツールとのI/Oレイヤ、KGを長期的な知識・関係のメモリ層として整理している。

```text
             Tools / APIs
                 ↑↓
                MCP
                 ↑↓
LLM  ←──────→  Knowledge Graph
```

MCPで外部から情報を取得できても、それだけでは組織固有の関係や過去の状態を継続的に保持するわけではない。取得した情報をKGなどの永続的な知識基盤へ反映し、後続の推論から参照できる形にすることで、I/OとMemoryを分離できる。

## Actionの前にも形式レイヤを置く

Agent型システムでは、回答生成より「実行」の方がリスクが大きい。

したがって、

```text
LLM proposes action
       ↓
Permission / Policy evaluation
       ↓
Human approval if required
       ↓
Tool execution
```

のように、LLMが決めた操作をそのまま外部システムへ流さない。

特に金額、削除、契約、顧客影響、権限変更のような操作では、Rule EngineやKG上の権限関係、人間承認を組み合わせる。

## このパターンの境界

形式レイヤを増やせば自動的に正しくなるわけではない。

Databaseの値、KGのRelation、Rule自体が間違っていれば、その誤りは決定論的に再現される。したがってこのパターンは、データ品質・Schema・Policy管理を不要にするものではない。

むしろ、**正しさの責任をLLMの内部から、検査・変更可能な外部構造へ移す**ための設計である。

## 関連

- [[RAG Limitations and Knowledge Graph]]
- [[Hybrid RAG and Knowledge Graph]]
- [[Enterprise Knowledge Graph Architecture]]
- [[Knowledge Graph for AI Agents]]

## 参考資料

- DevRev-JP, 「LLMをもっと賢くする：ナレッジグラフ実践入門」
- https://github.com/DevRev-JP/tech-blog/tree/main/books/knowledge-graph-llm-guide
- 主に `enterprise-kg-architecture.md` を整理。