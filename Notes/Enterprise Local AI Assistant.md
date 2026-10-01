# 企業向け完全ローカルAIアシスタント

社員にChatGPTやClaudeを使わせたくても、社内のセキュリティ規定で外部の生成AIへ社内情報を入力できない会社がある。
そうした会社向けに、社内の専門用語や規程を理解し、外部へデータを送らずに使えるChatベースのローカルLLMを用意する、という題材がある。

このノートは、2026-09-19の会話で学習題材を変更した際の設計を整理したものである。
当初の題材は問い合わせ分類だったが、利用者が「AIを導入するメリットがなさそう」と指摘し、こちらへ変更した。
その際、専門用語を扱うために **検索拡張生成（Retrieval-Augmented Generation, RAG）** や **MCP（Model Context Protocol）** などが必要かという問いが出た。

## 最終的に提供するのはモデル単体ではない

題材を変えたことで、最終的な商品像が変わった。
単なる「微調整済みLLM」ではなく、**社内データを外部へ出さず、社内用語・規程・資料を理解し、必要なら社内システムも操作できるローカルAIアシスタント**になる。

専門用語を理解させるために、すべてをモデルへ学習させる必要はない。
RAG、微調整、MCPに役割を分担させることが重要である。

## RAG、微調整、MCPは役割が違う

**RAG**は、質問されたときに関連文書を検索し、その内容をLLMへ渡して回答させる仕組みである。
**MCP**は、モデルへ資料（Resources）、道具（Tools）、定型指示（Prompts）を提供するための接続規格である。
MCPは専門知識を学習させる技術ではなく、モデルと社内システムをつなぐ仕組みである。

架空企業に「AX-17」「赤伝」「P3申請」「Nexus案件」のような社内用語があるとして、役割を分けると次のようになる。

| やりたいこと | 主に使うもの | 理由 |
|---|---|---|
| 「AX-17とは何？」に答える | RAG | 社内資料から定義を探せる |
| 最新の社内規程に基づいて答える | RAG | モデルを再学習せずに資料を更新できる |
| 「赤伝」という言葉を自然に使わせる | 微調整 | 話し方や使い方をモデル側へ寄せられる |
| 社内独自の回答形式を守らせる | 微調整 | 振る舞いを定着させやすい |
| SharePointから最新資料を取る | MCPなどの道具接続 | 外部システムへアクセスするため |
| チケットを検索する | MCPなど | 動的なデータ取得 |
| チケットを登録する | MCPなど | 実際の操作 |
| 社内文書だけを根拠に回答させる | RAG + 安全柵（Guardrail） | 根拠を制限できる |

したがって、この商品では **RAGはほぼ必須、MCPは後から追加、微調整は必要性を測って追加** という順番がよい。

## 知識はRAGへ、振る舞いは微調整へ寄せる

たとえば「PX申請とは、設備変更額が100万円を超える際に必要となる事前申請である」という社内ルールがあるとする。

これを微調整でモデルの重みへ焼き込むと、2027年の規程改定で基準が50万円へ変わったときにモデルの知識が古くなる。
再学習が必要になる。

RAGなら、`規程2026.pdf` を `規程2027.pdf` へ差し替えれば、次の質問から新しい規程で答えられる。

そのため基本原則を次のように置く。

- **事実、規程、製品情報、社内用語の定義 → RAG**
- **行動、文体、判断の仕方 → 微調整**

微調整を検討するのは、たとえば次のような振る舞いを定着させたい場合である。

- 回答するときは必ず社内用語を正式名称と併記する。
- 技術部向けの文章の書き方をする。
- この会社ではこの種類の質問にはこういう考え方で答える。
- 結論から答える。
- 不明な場合は推測せず資料確認を促す。
- 回答をこのJSON形式にする。

```text
Knowledge
「何を知っているか」
        ↓
       RAG

Behavior
「どう答えるか」
        ↓
 Fine-tuning
```

この区別は、LLMの **事前学習（Pre-training）** と **事後学習（Post-training）** の役割分担にも対応する。
事前学習は主に知識と言語能力を、事後学習は主に質問への答え方を学ぶ段階である。
ただし両者は完全には分離しておらず、事後学習でも知識を多少覚え、事前学習でも回答らしい書き方を学ぶ。
それでも設計では、知識を持たせる処理と望ましい振る舞いを教える処理を分けて考えると役に立つ。
詳しくは [[Neural Network Basics for LLM|LLMを理解するためのニューラルネットワーク基礎]] にまとめている。

```text
基盤モデル
    │
    ├─ もともとの一般知識
    │
    ├─ RAG
    │    └─ 会社固有の知識、最新資料
    │
    └─ Fine-tuning
         └─ 会社固有の振る舞い、回答方式
```

## 学習用の架空企業 Aster Industries

学習用に、架空の製造会社 **Aster Industries** を一社作る。
この会社には外部生成AIの禁止規定があり、ChatGPTやClaudeへ社内情報を入力できない。

それでも社員は、AIへ次のようなことを聞きたい。

- 「P3申請ってどうやるの？」
- 「AX-17の障害対応手順を教えて」
- 「Nexus案件でRed Gateを通す条件は？」
- 「この設計変更は品質保証部への申請が必要？」
- 「この資料を要約して」

最終的に作る構成は次の通りである。

```text
社員
 │
 ▼
社内Chat UI
 │
 ▼
Local LLM
 │
 ├──────── RAG
 │             │
 │        社内規程
 │        マニュアル
 │        用語集
 │        過去資料
 │
 └──────── MCP / Tools
               │
           SharePoint
           Git
           Ticket
           社内DB
```

**外部APIへ社内データを一切送らない構成**を最終目標にする。
これなら現実的な企業向けの **概念実証（Proof of Concept, PoC）** になる。

## 架空の社内データは自分で作れる

実データがなくても、実習用の社内データを疑似的に作れる。

```text
company-data/
├── glossary/
│   └── internal_terms.md
├── regulations/
│   ├── information_security.md
│   ├── ai_usage_policy.md
│   └── document_handling.md
├── manuals/
│   ├── nexus_manual.md
│   ├── red_gate.md
│   └── incident_response.md
├── products/
│   ├── ax17.md
│   └── ax21.md
└── qa/
    └── employee_questions.jsonl
```

架空用語の例は次の通りである。

| 用語 | 意味 |
|---|---|
| Nexus | 社内開発案件管理制度 |
| Red Gate | 本番リリース前のセキュリティ審査 |
| P3 | 重要度3以上の設備変更申請 |
| AX-17 | Aster Industries製の制御モジュール |

一般のLLMはこれらを知らない。
そのため、次の変化をすべて自分で体験できる教材になる。

```text
「Red Gateとは何ですか？」と聞く
↓
Base Modelは答えられない
↓
RAGを付ける → 答えられる
↓
Hybrid RAGにする → 似た型番でも間違えなくなる
↓
Fine-tuningする → 会社独自の回答スタイルになる
```

## 型番や略称には意味検索だけでは足りない

社内には `AX-17`、`AX17`、`AX-170`、`AX-71` のような似た型番がある。

埋め込みによる **意味検索（Semantic Search、Dense Search）** は、意味の近さを探すのは得意である。
しかし、型番、略称、製品番号の完全一致は別の問題になる。

そこで実務版では、次の構成まで作る。

```text
質問「AX-17の交換条件は？」
      ↓
┌──────────────┐
│ Dense Search │ ← 意味
└──────────────┘
       +
┌──────────────┐
│ BM25 Search  │ ← AX-17という文字列
└──────────────┘
      ↓
Hybrid Search
      ↓
Reranker
      ↓
LLM
```

**BM25**は、語の一致に基づいて文書を順位付けする字句検索の方法である。
意味検索と字句検索を組み合わせたものを **ハイブリッド検索（Hybrid Search）** と呼ぶ。
**再順位付けモデル（Reranker）** は、取得した候補を質問との関連度で並べ直すモデルである。

会話時点では、ベクトルデータベースのQdrantも、意味検索とSparse/BM25による字句検索を組み合わせるハイブリッド検索と、その後の再順位付けを公式に案内していると説明されている。
社内固有の型番や略語が多い環境と相性がよい設計である。

会話中の思考メモでは、略語や新語が多い場合に、BM25、ベクトル検索、再順位付け、メタデータ、権限制御、出典表示を組み合わせる方針も挙がっていた。

## RAGは検索と生成の二段階で評価する

ChatGPT風の画面を作り、「答えがそれっぽい」で終えてはいけない。
RAGは二段階で評価する。

```text
質問
 ↓
Retrieval
 ↓
正しい資料を取得できたか？
 ↓
Generation
 ↓
取得した資料から正しく回答したか？
```

まず、質問ごとに正解の文書をあらかじめ決める。
たとえば「AX-17の交換条件は？」の正解文書は `ax17.md` の Section 4 である。

検索（Retrieval）は次の指標で評価する。

- **Recall@5**：上位5件に正解文書が含まれる割合。
- **MRR（Mean Reciprocal Rank）**：正解文書が何位に出たかの逆数の平均。
- **Hit Rate**：正解文書を取得できた割合。

生成（Generation）は次の観点で評価する。

- 正答性
- 根拠との一致
- 引用の正確性
- **幻覚（Hallucination）**、つまり根拠のない内容を作っていないか

これは最終的に「この企業のテスト質問500件に対して、必要資料取得率98.2%、回答正答率94.7%」のような納品時の根拠につながる。
この数値は会話中の例示である。

## MCPは「現在の状態を見る・操作する」ために後から入れる

最初のAIは、「Nexus案件の承認条件は？」という質問に対してRAGで社内規程を検索するだけである。

MCPを追加すると、次のことができる。

```text
社員：
「俺が担当しているNexus案件のうち、
Red Gateを通っていないものを教えて」
        ↓
LLM
 ↓
MCP Tool
 ↓
Project Management System
 ↓
現在の案件一覧
```

さらに「NEX-284の担当者にレビュー依頼を登録して」のような操作まで行える。

```text
RAG → 「社内の知識を知る」
MCP → 「社内の現在の状態を見る・操作する」
```

MCPの公式仕様でも、Resourcesは文脈データ、Toolsはモデルが実行できる機能として分けられている。

## すべての部品がローカルであることを確認する

顧客がローカルLLMを導入するのは、ChatGPTやClaudeへ社内データを送れないからである。
それなら、次の部品まで全部ローカルであることを確認する必要がある。

- Local LLM
- Local Embedding
- Local Reranker
- Local Vector DB
- Local Document Parser
- Local Chat UI

埋め込みだけ外部APIを使っていたら意味がない。

## 検索にも権限制御が必要になる

実際の企業には、閲覧権限の階層がある。

```text
一般社員 → 一般文書のみ
部長     → 部門機密まで
役員     → 経営資料
```

そのため、RAGにも利用者の権限に応じて検索対象を絞る **権限を考慮した検索（ACL-aware Retrieval）** が必要になる。
**ACL（Access Control List）** は、誰がどの資料へアクセスできるかを定めた一覧である。
「ベクトルDBに入っているから全社員が検索可能」では、企業システムとして危険である。

ロードマップでは、権限、機密情報、**指示の乗っ取り（Prompt Injection）** 対策をSecurityとして独立したPhaseにしている。

## RTX 4070 12GBでの実習構成

12GB VRAMなら、実習用構成として十分だとされている。

```text
RTX 4070 12GB
Local LLM（3B～8B / 4bit）
+ Embedding Model（小型）
+ Reranker（小型）
+ Qdrant（CPU/RAM）
+ Web UI
```

全部を常時GPUへ載せる必要はない。
埋め込みや再順位付けをCPUへ逃がす実験もできる。

微調整の段階では、まず3B前後のQLoRAで確実に理解し、その後7〜8B級へ挑戦する。

## 最終成果物はテンプレートとして残す

学習が終わったときに持っていたいのは、次の **Enterprise Local AI Template** である。

```text
Enterprise Local AI Template

Base Model
    ├── Fine-tuning
    ├── Quantization
    └── Inference
RAG
    ├── Ingestion
    ├── Embedding
    ├── Hybrid Search
    ├── Reranking
    └── ACL
MCP / Tools
Security
Evaluation
Web Chat
```

当初考えていた「企業専用LLMを販売する」から、**企業専用の完全ローカル生成AI基盤を構築し、その中で必要に応じて専用モデルまで作れる**形へ発展している。

RAGを微調整より先に経験することで、「何でもモデルへ学習させればいいわけではない」ことを実際に確認できる。
具体的な順序は [[Custom Model Learning Roadmap|企業専用モデルの学習ロードマップ]] の改訂版に整理している。

## 関連

- [[Enterprise Model Distillation|企業向け蒸留モデル]]
- [[Custom Model Business|企業専用モデルの販売事業]]
- [[Custom Model Learning Roadmap|企業専用モデルの学習ロードマップ]]
- [[Hybrid RAG and Knowledge Graph|検索拡張生成とナレッジグラフの併用]]
- [[RAG Limitations and Knowledge Graph|検索拡張生成の限界とナレッジグラフ]]
- [[Formal Layer Sandwich for Enterprise AI|業務AIを決定論的な層で挟む設計]]
- [[AI Projects Overview|AIプロジェクト概要]]

## 参考資料

- Model Context Protocol, *Specification: Server Overview*（2025-06-18）
- https://modelcontextprotocol.io/specification/2025-06-18/server
- Hugging Face, *Expanding Chat Templates with Tools and Documents*
- https://huggingface.co/docs/transformers/main/chat_template_tools_and_documents
- Qdrant, *Hybrid Search with Reranking*
- https://qdrant.tech/documentation/tutorials-basics/reranking-hybrid-search/
- 原本：[[Sources/Model Distillation/ChatGPT-企業向け蒸留モデル解説-20261001-1717.md]]
#lesson
