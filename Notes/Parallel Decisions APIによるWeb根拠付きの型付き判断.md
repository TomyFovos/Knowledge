---
type: Reference
status: Researching
topics: [Parallel Decisions API, 型付き判断, Web検索, 判断ログ]
follow_up: true
follow_up_type: research
created: "2026-11-02"
updated: "2026-11-02"
---

# Parallel Decisions APIによるWeb根拠付きの型付き判断

Parallel Decisions APIは、前提`state`と名前付き質問を受け取り、Webで集めた根拠から型付きの答えと確率、引用URLを返す仕組みとして紹介される。提供資料の調査日は2026-11-02で、今回の取り込みではAPI呼び出しや外部確認を行っていない。

## 入出力と正常な回答拒否

| 型 | 資料の説明 |
|---|---|
| `noul` | 条件が真である確率 |
| `choice` | 選んだラベルと選択肢別の確率 |
| `score` | 順序付き段階の番号を確率で重み付けした平均 |
| `refusal` | 答えられないという正常な返答 |

資料では`POST /v1/decisions`に共通stateと最大100問を送り、同じ検索材料で判定する。`answers`は送信時の質問名で引く。紹介画像のように全回答から`noul`だけを読まず、`type`で分岐する必要がある。`refusal`はHTTPエラーではないため、HTTP成功判定だけでは見つからない。

`citations`は呼び出し全体の根拠であり、質問ごとの根拠対応が返るとはされていない。確率から採否へ変換する閾値も利用側の判断になる。

## 他方式との境界

```text
手元の前提・材料だけで判定 → 決定モデルを検討
新しく変わるWeb事実も必要 → Web取得付きの判断APIを検討
```

JevやOpenAIのDecisions APIとの比較も原資料にあるが、提供条件・型の細部を今回公式資料で再確認したものではない。Parallelの内部判断モデルも公開情報からは特定できない、と記録されている。

0.5〜0.9秒程度、426社の確認事例等は提供側の報告であり、任意の質問での速度・精度保証ではない。`choice`・`score`の仕様の一部は外部解説由来である。

## RustXNGや承認ログへの応用は検討案

RustXNGを前段に置いて速くなるとの実証はない。メタ検索の結果取得と本文・根拠抽出は別で、Parallel内部の検索時間や索引反映時間も未確認。組み合わせによる鮮度改善は仮説として残す。

操作前の人間承認要否を記録する用途では、線引きと操作内容が手元にあるなら、Web検索を挟まない判定方式が候補になるという会話の整理である。項目別の確率を残すと、閾値のずれと分類自体の誤りを区別しやすい。

この確率は判断材料であり、正式な許可・権限の代替とは扱わない。自動的に精度が改善するという話でもなく、正解付きログの評価と質問・基準の見直しが必要になる。

## 関連・参考資料

- [[RustXNGによるメタ検索と組織内検索]]
- [[Treg Web AccessによるSEOエージェントの情報取得改善]]
- [[AI実行ガバナンスと人間の監督]]
- 原本：[[Sources/Knowledge Batch 20261102/Parallel Decisions APIの型付き判断とWeb根拠の元資料]]。
- 元ファイル：`ParallelDecisionsAPI-Knowledge-20261102.md`。
- 提供資料の主な参照先：[紹介記事](https://parallel.ai/blog/decisions-api)、[Quickstart](https://docs.parallel.ai/decisions/decisions-quickstart)。
