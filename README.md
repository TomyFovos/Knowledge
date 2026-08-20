# Knowledge Base

AI・ソフトウェア開発を中心に、**方法論・設計思想・ツール・アイデア・実験結果・学び**を蓄積するための共有ナレッジベースです。

このVaultでは、完成された文書だけを残すのではなく、

**思いつく → 調べる → 試す → 判断する → 知識として残す**

までの過程も含めて記録します。

---

## 目的

AIの進歩によって、新しい技術・方法論・開発手法・ツールが非常に速い速度で登場しています。

それらを個人の記憶やチャット履歴だけに残すのではなく、チームで再利用できる形に整理・蓄積することを目的とします。

主に以下を記録します。

* AI・LLMに関する技術
* AI Agent / Multi-Agent
* Context Engineering
* Harness Design
* Tool Calling
* Evaluation / Benchmark
* AI駆動開発
* ソフトウェア設計
* テスト手法
* CI/CD
* 開発方法論
* 新しいツール・サービス
* 実験結果
* 設計上の判断
* 失敗から得た知見
* 今後試したいアイデア

---

# 基本方針

## 1. まず書く

整理されていなくても構いません。

「後でまとめてから書く」ではなく、思いついた段階で残してください。

迷った場合は `00_Inbox` に入れます。

---

## 2. 1ノート1テーマ

可能な限り、1つのノートには1つのテーマを扱います。

例：

```text
良い例

Context Engineering.md
Multi-Agent.md
LLM Evaluation.md
Agent Harness.md
```

```text
避けたい例

AIについて色々.md
最近調べたこと.md
メモ.md
```

---

## 3. 関連するノートをリンクする

Obsidianの内部リンクを積極的に使用します。

```md
[[Context Engineering]]
[[Agent Harness]]
[[Multi-Agent]]
```

知識をフォルダだけで分類するのではなく、**ノート同士の関係性も残す**ことを重視します。

---

## 4. 完成度を求めない

途中の考察や未検証のアイデアも記録対象です。

その代わり、

* Idea
* Researching
* Experimenting
* Adopted
* Rejected

など、現在の状態が分かるようにします。

---

# ディレクトリ構成

```text
Knowledge/
│
├── 00_Inbox/
│
├── 01_Concepts/
│
├── 02_Methodologies/
│
├── 03_Patterns/
│
├── 04_Systems/
│
├── 05_Ideas/
│
├── 06_Experiments/
│
├── 07_Decisions/
│
├── 08_Lessons/
│
├── 09_References/
│
└── 99_Archive/
```

---

## 00_Inbox

まだ分類していないメモを置きます。

思いついたことはまずここに書いて構いません。

定期的に他のフォルダへ移動します。

---

## 01_Concepts

概念や技術そのものについてまとめます。

例：

```text
AI Agent
Context Engineering
RAG
Memory
MCP
Tool Calling
Agent Runtime
Evaluation
Observability
```

---

## 02_Methodologies

開発方法論・考え方・進め方をまとめます。

例：

```text
AI Driven Development
Spec Driven Development
TDD
DDD
Agentic Coding
Human in the Loop
```

---

## 03_Patterns

繰り返し利用できる設計・実装・運用パターンをまとめます。

例：

```text
Agent Handoff
Recovery Pattern
Context Compression
Human Approval Gate
Fallback Strategy
Multi-Agent Coordinator
```

---

## 04_Systems

具体的なツール・サービス・フレームワークについてまとめます。

例：

```text
Claude Code
Codex
OpenCode
GitHub Actions
Obsidian
Playwright
```

---

## 05_Ideas

まだ採用するか決まっていないアイデアを置きます。

荒いアイデアでも構いません。

---

## 06_Experiments

実際に試した内容と結果を記録します。

成功だけでなく、失敗した実験も残します。

---

## 07_Decisions

チームとして行った重要な判断を記録します。

例：

```text
なぜ○○を採用したか
なぜ○○を採用しなかったか
どの選択肢を比較したか
判断時点では何が分かっていたか
```

後から判断理由を追跡できることを重視します。

---

## 08_Lessons

実際の開発・運用・実験から得られた知見を記録します。

特に、

```text
失敗したこと
想定と違ったこと
再発防止
次回やるべきこと
```

を積極的に残します。

---

## 09_References

外部資料を整理します。

例：

* 論文
* 技術記事
* GitHub Repository
* Documentation
* 動画
* 書籍
* ブログ

リンクだけではなく、可能であれば

**「なぜ重要なのか」**

を1〜3行程度残します。

---

## 99_Archive

現在は使用していない情報を保管します。

削除するか迷った場合はこちらへ移動します。

---

# ノートの推奨フォーマット

すべての項目を書く必要はありません。

```md
# タイトル

## 概要

これは何か。

## なぜ重要か

何に使えるのか。
何を解決するのか。

## 内容

調査した内容や考え。

## 関連

- [[関連ノート]]
- [[関連ノート]]

## 参考資料

- URL
- URL
```

---

# Ideaの推奨フォーマット

```md
# アイデア名

Status: Idea

## アイデア

何を思いついたか。

## 背景

なぜ必要だと思ったか。

## 期待する効果

何が改善されるか。

## 課題

現時点で分かっている問題。

## 次に試すこと

実験・調査する内容。

## 関連

- [[関連ノート]]
```

---

# Experimentの推奨フォーマット

```md
# 実験名

Status: Experimenting

## 目的

何を確認する実験か。

## 仮説

どうなると予想しているか。

## 方法

どのように確認したか。

## 結果

実際にどうなったか。

## 考察

なぜその結果になったか。

## 次のアクション

- 継続
- 改善
- 採用
- 不採用
- 再実験
```

---

# Decisionの推奨フォーマット

```md
# 判断内容

Status: Adopted

## 背景

何について判断する必要があったか。

## 選択肢

### A

### B

### C

## 判断

採用した選択肢。

## 理由

なぜその判断をしたか。

## デメリット

採用によって受け入れる問題。

## 再検討条件

どのような状況になったら再検討するか。
```

---

# タグについて

タグは増やしすぎないようにします。

基本的にはフォルダとリンクを中心に整理します。

タグを使う場合は、用途を限定します。

例：

```text
#idea
#experiment
#decision
#lesson
#draft
```

技術分類をすべてタグで管理する必要はありません。

---

# ファイル名

内容が分かる名前を付けます。

```text
良い例

Context Engineering.md
Agent Harness.md
Multi-Agent Architecture.md
Platform Test.md
```

```text
避けたい例

メモ1.md
調査.md
新規メモ.md
2026-08-20.md
```

日付自体が重要な場合のみ日付を付けます。

---

# 情報が重複した場合

似たノートが存在する場合は、すぐに統合する必要はありません。

まずリンクします。

```md
関連: [[既存ノート]]
```

内容が十分まとまってから統合します。

「重複を恐れて書かない」ことの方を避けます。

---

# チームでの運用

このKnowledge Baseは、特定の人だけが整理する場所ではありません。

気付いた人が追加・修正してください。

ただし、

**他の人が書いた内容を大きく変更する場合は、元の意図を失わないよう注意してください。**

意見が異なる場合は既存内容を消すのではなく、

```md
## 別の見方

...
```

のように併記することを推奨します。

---

# Todoist / GitHubとの使い分け

役割を分けます。

```text
Obsidian
↓
知識・アイデア・調査結果・設計思想

Todoist
↓
個人のTODO・忘れないためのタスク

GitHub Issues
↓
実際に開発するタスク・不具合・改善
```

Obsidianに実装すべきアイデアが生まれた場合はGitHub Issueへ移します。

Issue側から必要に応じてObsidianのノートを参照します。

---

# このKnowledge Baseで大切にすること

このVaultの目的は、

**綺麗なドキュメントを作ることではありません。**

重要なのは、

> 過去に誰かが考えたことを、未来の誰かが再利用できること。

です。

そのため、

**書く → 繋げる → 試す → 更新する**

ことを優先します。
