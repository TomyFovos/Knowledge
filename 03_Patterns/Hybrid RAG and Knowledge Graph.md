# Hybrid RAG and Knowledge Graph

## 概要

RAGとKnowledge Graphは競合関係ではない。

RAGは非構造化テキストから関連文脈を探すことに向き、KGはエンティティ間の関係を構造化して保持・探索することに向く。実用上は、質問の種類に応じて両者を使い分け、必要なら両方の結果をLLMへ渡す構成が強い。

```text
Question
  ├─ contextual question → RAG
  ├─ structural question → KG
  └─ mixed question      → RAG + KG
                           ↓
                          LLM
```

## KGが得意な5種類の問い

元資料では、KGが特に強い問いを五つに整理している。

### 1. 集合・分類

複数条件を満たす対象を正確な集合として求める。

例: 「Criticalで、Backendチームが担当しているOpen Bug」

### 2. 対比・差分

二つの対象が持つ関係・属性の差を明示する。

例: 「Auth ServiceとUser Serviceが利用するライブラリの差」

### 3. 経路・関係探索

多段の依存・因果・所属関係を辿る。

例: 「Auth ServiceからDatabase Serviceまでの依存経路」

### 4. 否定・除外

関係が存在しない対象を求める。

例: 「担当者がいないBug」「TestSuiteがないComponent」

### 5. カウント・集計

構造を条件に件数や分布を算出する。

例: 「チーム別のOpen Bug数」

これらは「似た文章を検索する」問題ではなく、構造化データへ問い合わせる問題である。

## RAGが得意な問い

RAGは文章の説明・背景・手順・設計意図のように、非構造化コンテンツそのものが答えになる問いへ向く。

例:

- 「Auth Serviceの設計思想を教えて」
- 「この障害の復旧手順を説明して」
- 「この仕様変更の背景は何か」

こうした情報をすべてグラフへ細分化すると、モデリングコストが高くなり、文章としての文脈も失われる。

## Hybrid Query Routing

すべての質問を一つの検索方式へ押し込まない。

質問分類器を置き、少なくとも次の三種類へ振り分ける。

```text
kg      : 集合、集計、経路、関係、否定、正確な事実
rag     : 背景、説明、手順、文章的文脈
hybrid  : 構造化された事実と文章文脈の両方
```

たとえば「BUG-001の修正方法と関連Componentを教えて」であれば、関連ComponentはKG、修正手順はRAGから取得し、最終的にLLMが統合する。

## LLMに任せる場所を限定する

LLMは質問分類、自然言語からCypherへの変換、複数ソースの説明統合に使える。

ただし、LLM生成Cypherをそのまま書き込み権限のあるDBで実行するのは危険である。元資料の実装例も、本番では読み取り専用ユーザーやクエリ検証を置く必要があると注意している。

このパターンの要点は、**LLMが事実を発明するのではなく、検索・構造問い合わせの結果を文章へ変換する位置に置くこと**にある。

## GraphRAGとの関係

元資料は、単純なVector RAGとKGを組み合わせる構成に加えてGraphRAGも扱う。

ここで重要なのは名称より、検索対象を一種類に限定しないことにある。文書の意味的近さと、Entity/Relationの構造は異なる情報を持つ。どちらを使うかは質問の性質によって決める。

## 関連

- [[Knowledge Graph]]
- [[RAG Limitations and Knowledge Graph]]
- [[Formal Layer Sandwich for Enterprise AI]]
- [[Knowledge Graph for AI Agents]]

## 参考資料

- DevRev-JP, 「LLMをもっと賢くする：ナレッジグラフ実践入門」
- https://github.com/DevRev-JP/tech-blog/tree/main/books/knowledge-graph-llm-guide
- 主に `beyond-rag-with-kg.md` を整理。