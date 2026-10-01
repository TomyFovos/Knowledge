# 企業専用モデルの学習ロードマップ

企業専用のローカルAIを作れると言うには、蒸留だけを覚えても足りない。
顧客要件の整理からデータセット、評価、学習、量子化、配備、ライセンスまでを一本通して経験する必要がある。

このノートは、2026-09-19〜20のChatGPTとの会話で作った学習ロードマップを整理したものである。
最終到達点は、**顧客企業から要件を聞き、オープンウェイトモデルを選定し、企業専用データで学習・評価・軽量化・ローカル配備し、技術的に納品可能な状態まで持っていけること**に置いている。

前提条件は次の通りである。

- 所有GPUはRTX 4070（デスクトップ版、VRAM 12GB）。
- 実データは用意できないため、疑似データでよい。販売目的ではない。
- 手を動かしながら一つずつ丁寧に理解する。
- 学習が終わったらブログにする予定で、学んだことや画面キャプチャを残していく。

## 中国系と非中国系のどちらにも対応できるよう、モデル非依存で学ぶ

オープンウェイトであっても中国系LLMを嫌う会社は多く、それ以外を選ぶと性能が落ちる。
商品にするなら、どちらにも対応できる状態にしておく必要がある。

そのため「QwenのFine-tuning方法」ではなく、Hugging Face系の任意の **因果言語モデル（Causal LM）** を差し替えられる学習基盤として学ぶ。
最後には同じパイプラインで、中国系Base Modelから `CompanyModel-A`、非中国系Base Modelから `CompanyModel-B` を作れる状態にする。

この考え方は [[Custom Model Business|企業専用モデルの販売事業]] の「商品は製造工程そのもの」という整理につながる。

## 蒸留の前に普通の微調整を理解する

投稿だけを見ると「巨大Teacher → 蒸留 → 4B」だけを覚えたくなる。
しかし、普通の **微調整（Fine-tuning）** とは何かが分かっていないと、蒸留で何が起きているかを理解できない。
そのため、いきなり蒸留には進まない。

実務では、次の工程がすべてつながっている。

```text
顧客要件
 ↓
Task定義
 ↓
Dataset
 ↓
Baseline
 ↓
Base Model選定
 ↓
Fine-tuning
 ↓
Distillation
 ↓
Evaluation
 ↓
Calibration
 ↓
Quantization
 ↓
Deployment
 ↓
License
 ↓
納品
```

**この一本を経験することが「企業専用モデルを作れる」の実体である。**

## 現行版：社内Chatを題材にした16段階のロードマップ

当初は問い合わせ分類を題材にした10段階のロードマップだった。
その後、題材を「外部生成AIを禁止された会社向けの、社内用語を扱えるローカルChat」へ変え、16段階へ改訂した。
題材変更の理由と設計は [[Enterprise Local AI Assistant|企業向け完全ローカルAIアシスタント]] にまとめている。

| Phase | テーマ | 実習で作るもの |
|---|---|---|
| 0 | LLM基礎 | TransformersからローカルLLMを直接動かす |
| 1 | Local Chat | ChatGPT風の完全ローカルChat |
| 2 | 架空企業データ | 社内規程・用語集・マニュアルを疑似作成 |
| 3 | RAG基礎 | 社内文書を検索して回答する |
| 4 | RAG実務 | Chunking・Embedding・Vector DB |
| 5 | Hybrid RAG | Dense + BM25 + Reranker |
| 6 | RAG評価 | 「正しい文書を取れたか」を測る |
| 7 | Fine-tuning | 社内らしい回答方法をLoRA/QLoRA学習 |
| 8 | RAG + Fine-tuning | 知識と振る舞いを分離した企業AI |
| 9 | Distillation | 高性能Teacher → 小型Local Student |
| 10 | MCP / Tools | 社内システム接続 |
| 11 | Security | 権限・機密情報・Prompt Injection対策 |
| 12 | Quantization | GGUF/4bit化・速度測定 |
| 13 | Deployment | Docker + API + Web UI |
| 14 | モデル比較 | 中国系/非中国系Baseを差し替える |
| 15 | 商品化 | 評価報告・ライセンス・導入手順・更新方法 |

**チャンク分割（Chunking）** は、文書を検索しやすい単位へ分割することである。
**ベクトルデータベース（Vector DB）** は、埋め込みベクトルを保存し、近いものを検索するためのデータベースである。

## RAGを微調整より先に置く

改訂版では、微調整より先にRAGを学ぶ。
最終商品を作るときに「微調整しなくてもRAGだけで十分ではないか」を判断できなければならないからである。
企業へ不要な微調整費用を売るような設計にはしたくない、という方針でもある。

RAGを先に経験してから微調整へ進むと、「何でもモデルへ学習させればいいわけではない」ことを実際に確認できる。

## 初版：分類モデルを題材にした10段階のロードマップ

初版は、架空の会社「Example Manufacturing」の専用AIを一本作る計画だった。
題材は、社内問い合わせを読んで「通常」「要確認」「緊急」の3段階に分類し、JSONで返すモデルである。

```text
入力文章
   ↓
企業専用 2B～4B モデル
   ↓
{
  "decision": "review",
  "confidence": 0.93,
  "category": "security"
}
```

| Phase | 学ぶこと | 実際に作るもの |
|---|---|---|
| 0 | LLMの内部構造と用語 | Baseモデルを直接動かす |
| 1 | Dataset設計 | 架空企業データセット |
| 2 | 評価設計 | 学習前Baseline |
| 3 | LoRA / QLoRA | 初の企業専用モデル |
| 4 | Fine-tuningの調整 | 過学習・学習率などを実験 |
| 5 | Synthetic Data | 疑似企業データを大量生成 |
| 6 | Distillation | Teacher → Student |
| 7 | 評価・Calibration | 信頼できる/できないを測る |
| 8 | Quantization・高速化 | GGUF等へ変換 |
| 9 | API・納品 | ローカルAIサーバ |
| 10 | 商用化 | ライセンス・モデルカード・納品物 |

題材は変わったが、初版の各Phaseの中身は、現行版の微調整、蒸留、量子化、配備、商品化の各Phaseでそのまま使える。
以下に初版の内容を残す。

### Phase 0：モデルを使う側から作る側へ

これまでの経験は、誰かが量子化したGGUFをBonsaiで推論するもので、モデルファイルはブラックボックスだった。
ここから、モデルの内部を理解する。

```text
Tokenizer
   ↓
Base Model
   ↓
Weights
   ↓
Forward Pass
   ↓
Logits
   ↓
Token
```

Transformerの数式を延々と勉強する必要はない。
理解するのは、Tokenizer、Token、Weight、Parameter、Logit、Context、Base model、Instruct model、Checkpointくらいである。

**トークナイザー（Tokenizer）** は文字列をトークンへ分割してIDへ変換する部品である。
**順伝播（Forward Pass）** は、入力から出力までモデルの計算を一度通すことである。
**ロジット（Logit）** は、次のトークン候補それぞれへの確率化前のスコアである。
**チェックポイント（Checkpoint）** は、学習途中や学習後の重みを保存したものである。

実習では、BonsaiやOllamaを経由せず、Hugging Face Transformersから小型モデルを直接読み込む。

```python
model = AutoModelForCausalLM.from_pretrained(...)
tokenizer = AutoTokenizer.from_pretrained(...)
```

ここで「GGUFになる前のモデルはこういうものか」を体験する。

**合格条件**：次の違いを自分の言葉で説明できたら終了する。

```text
モデル / 重み / パラメータ
Base Model / Instruct Model
FP16 / INT8 / INT4 / GGUF
Tokenizer / Token
推論 / 学習
```

期間は半日〜1日で十分とされている。

### Phase 1：データセットを作る

モデルより先にデータセットを作る。
最初はPythonで疑似生成すれば十分である。

```text
PCが起動しません → normal
取引先へ誤って顧客一覧を添付しました → emergency
パスワードを変更したいです → normal
知らないIPから管理者ログインされています → emergency
請求書の金額がおかしい気がします → review
```

```json
{
  "text": "顧客情報を誤った宛先に送信しました",
  "decision": "emergency"
}
```

このようなデータを1,000〜3,000件作る。

データは **学習用（Train）**、**検証用（Validation）**、**テスト用（Test）** に分ける。
例：Train 2000、Validation 300、Test 500。
Testは最後までモデルに見せない。

ここで覚える概念は次の通りである。

- **ラベル（Label）**：正解として付ける値。
- **クラスの偏り（Class balance）**：ラベルごとの件数の偏り。
- **データ漏洩（Data leakage）**：テスト用データの情報が学習に混入すること。
- **Train / Validation / Test**
- **分布（Distribution）**：データの性質や偏り。
- **境界事例（Edge case）**：判断が難しい端のケース。
- **紛らわしい負例（Hard negative）**：正解に似ているが正解ではない例。

企業専用モデルを販売するなら、モデルそのものよりこの知識の方が重要だとされている。
期間は2〜3日程度。

### Phase 2：学習する前に性能を測る

いきなり微調整しない。
まず何も学習していないモデルに、「この文章を normal / review / emergency のどれかに分類してください」と命令し、500件のTestデータへ回答させる。

たとえば Accuracy 72%、F1 0.68 となれば、これが **基準値（Baseline）** である。
微調整後に72%から91%へ上がって初めて、学習に意味があったと言える。

ここで次の指標を実際に計算する。

- **正解率（Accuracy）**：全体のうち正解した割合。
- **適合率（Precision）**：陽性と判定したもののうち、本当に陽性だった割合。
- **再現率（Recall）**：本当の陽性のうち、陽性と判定できた割合。
- **F1**：適合率と再現率の調和平均。
- **混同行列（Confusion Matrix）**：正解ラベルと予測ラベルの組み合わせごとの件数表。

期間は1〜2日。

### Phase 3：初めてLoRA / QLoRAする

最初の大きな山であり、RTX 4070を本格的に使う。

2B〜4B程度のBase Modelを選ぶ。
モデル全体を書き換えるのではなく、非常に小さい追加の重みだけを学習させる。

```text
Original weights
████████████████████

LoRA
         ██
```

ここでLoRAとQLoRAの違いを理解する。
QLoRAは、Base Modelを4bitに量子化し、LoRA AdapterをBF16/FP16で学習する形なので、4070との相性が非常によい。

使う中心ライブラリは次の通りである。

- PyTorch
- Transformers
- Datasets
- **PEFT**（LoRAなどの軽量な微調整手法を提供するライブラリ）
- **TRL**（SFTなどの学習処理を提供するライブラリ）
- Accelerate

最初から便利ツールだけに依存せず、これらの関係を理解する。
その後Unslothなどを使うと、Unslothが何を高速化しているかも理解できる。

成果物は次のようなアダプターである。
これが初めての「自分で作ったモデルWeight」になる。

```text
example-company-adapter/
 ├ adapter_config.json
 └ adapter_model.safetensors
```

期間は3〜5日。

### Phase 4：学習すれば良くなるわけではないことを学ぶ

同じデータセットで、epoch = 1、3、10を比較する。
**エポック（Epoch）** は、学習データ全体を一巡する単位である。

```text
Train accuracy
1 epoch  → 85%
3 epoch  → 96%
10 epoch → 99%

Test accuracy
1 epoch  → 81%
3 epoch  → 91%
10 epoch → 78%
```

このように、学習データでは良くなり続けるのに未知データでは悪くなる現象が起きる。
これが **過学習（Overfitting）** である。
数値は会話中の例示である。

さらに次のハイパーパラメータを少しずつ触る。

- **学習率（Learning rate）**：一回の更新で重みをどれだけ動かすか。
- **バッチサイズ（Batch size）**：一回の更新に使うデータ件数。
- **勾配累積（Gradient accumulation）**：複数回分の勾配をためてから更新し、実質的なバッチサイズを大きくする方法。
- **系列長（Sequence length）**：一度に扱うトークン数。
- Epoch
- **ウォームアップ（Warmup）**：学習初期に学習率を徐々に上げること。
- **重み減衰（Weight decay）**：重みが大きくなりすぎないよう抑える正則化。

ここで「Fine-tuningする」の意味が具体的になる。
期間は2〜4日。

### Phase 5：合成データを作る

現実の企業では、正解付きデータが500件しかないことがある。
そこで教師モデルに「この例と似ているが、内容の異なる事例を100件作れ」と依頼し、実データ500件に合成データ10,000件を加えるように増やす。

ただし、LLMが生成したから正解というわけではない。
次の処理を行う。

- **選別（Filtering）**
- **重複除去（Deduplication）**
- **品質確認（Quality check）**
- **クラスの偏りの調整（Class balance）**

この工程が **合成データパイプライン（Synthetic Data Pipeline）** である。
期間は2〜4日。

### Phase 6：蒸留

ここで投稿と同じ領域へ入る。
例として、Teacherに8Bモデル、Studentに2Bモデルを用意する。

Teacherに大量の文章について、分類、確信度、理由を生成させる。

```json
{
  "decision": "emergency",
  "confidence": 0.97,
  "reason": "customer data was sent externally"
}
```

それを50,000件程度Studentへ学習させ、次のように比較する。
数値は会話中の例示である。

| | Accuracy | Latency | VRAM |
|---|---:|---:|---:|
| Teacher 8B | 94% | 120ms | 8GB |
| Student 2B | 92% | 25ms | 2GB |

ここまで来ると、「巨大モデルの判断を4Bに移す」が体験として理解できる。

### Phase 7：「Accuracy 95%だから安全」を卒業する

商品化するなら必須のPhaseである。

正常メール9,500件、事故メール500件のデータでは、全部を「正常」と答えるモデルでもAccuracyは95%になる。
これでは役に立たない。

そこで、Precision、Recall、F1、**誤検出（False Positive）**、**見逃し（False Negative）** を見る。

さらに重要なのが **確信度（Confidence）** と **較正（Calibration）** である。
較正とは、モデルが0.99と言ったものが本当に99%正しいかを確認し、確信度と実際の正解率を合わせることである。

そのうえで、確信度に応じて処理を分ける **回答保留の設計（Abstention設計）** を行う。

```text
confidence >= 0.95 → 自動処理
0.70～0.95       → 人間確認
< 0.70           → 拒否
```

ここまで来れば企業案件としてかなりまともになる。
期間は3〜5日。

### Phase 8：量子化

ここでBonsaiの経験と接続する。
微調整したモデルを BF16 → 8bit → 4bit → GGUF と変換し、次のように比較する。

| Model | VRAM | Latency | Accuracy |
|---|---:|---:|---:|
| BF16 | 大 | 遅い | 92.3% |
| 8bit | 中 | 中 | 92.2% |
| 4bit | 小 | 速い | 91.8% |

量子化すると本当にどれくらい性能が落ちるかを自分で確認する。
「GGUFを使ったことがある」から「自分で作ったモデルをGGUFにする」へ変わる。

### Phase 9：商品の形にする

ここからはモデル研究ではなくシステム開発である。

```text
Client
   ↓
REST API
   ↓
Local Model
   ↓
JSON response
```

たとえば `POST /classify` に対して `{"decision": "emergency", "confidence": 0.96}` を返す。
さらに Docker → NVIDIA Container Runtime → Inference Server まで作り、最終的には `docker compose up -d` だけで顧客環境へ導入できるところまで持っていく。

### Phase 10：動くモデルから販売できるモデルへ

技術的に動くだけでは販売できない。
モデルごとに次を記録する。

- Base model license
- Teacher model terms
- Dataset license
- Synthetic data terms
- Fine-tuned model ownership
- Redistribution
- Commercial use

納品物として次を作る。
これが企業向けの完成形である。

```text
Model
Adapter
Tokenizer

model-card.md
evaluation-report.pdf
license-report.md
dataset-card.md
deployment-guide.md
```

**モデルカード（Model Card）** は、モデルの用途、学習データ、評価結果、制約などをまとめた文書である。

## RTX 4070 12GBでできる範囲

会話時点の目安として、ChatGPTは次のように整理している。

| 作業 | RTX 4070 |
|---|---|
| 1〜4B推論 | ◎ |
| 7〜8B 4bit推論 | ◎ |
| 12B前後 4bit推論 | ○ 条件次第 |
| 1〜4B QLoRA | ◎ |
| 7〜8B QLoRA | ○ 工夫が必要 |
| 12B QLoRA | △ |
| 1〜4B Full Fine-tune | △〜× |
| 70B学習 | × |
| 小型Student蒸留 | ◎ |

1B〜4B級は扱いやすく、7B〜8B級もQLoRAなら条件を絞って学習可能で、巨大Teacherは学習せず推論専用にする、という切り分けである。

勉強では、Teacherを7B〜12Bで推論のみに使い、Studentを1B〜4Bで学習させるとちょうどよい。

巨大Teacherを使う本番案件では、生成と学習を分離できる。

```text
Cloud GPUでTeacher生成
↓
生成済Dataset
↓
ローカル4070でStudent学習
```

## 各Phaseは同じ型で進める

各Phaseは次の順で進める。

1. まず概念を理解する。
2. RTX 4070で実際に実行する。
3. 結果を見る。
4. なぜそうなったかを理解する。
5. 成果物をGitへ残す。

途中で「分かったつもり」のまま次へ進まないことを重視している。

最終的に一つのリポジトリが次のように育つ。
初版では `enterprise-model-lab/`、実際の作業では `~/projects/enterprise-local-ai-lab` という名前を使っている。

```text
enterprise-model-lab/
├── datasets/
├── experiments/
├── training/
├── distillation/
├── evaluation/
├── quantization/
├── server/
└── docs/
```

単なる勉強記録ではなく、将来本当に案件を受けたときに、このLabを企業案件用テンプレートへ発展させられる。

## Phase 0の細分化と進捗

Phase 0は、「BonsaiでGGUFを動かす」から「元のオープンウェイトモデルを自分で扱う」へ移ることだけを目標にする。

| Step | やること | 理解するもの |
|---|---|---|
| 0-A | GPU学習環境を作る | CUDA / PyTorch / VRAM |
| 0-B | 元モデルを直接ロードする | safetensors / Weight / Parameter |
| 0-C | モデル内部を観察する | Tokenizer / Token / Logit |
| 0-D | BaseとInstructを比較する | Pre-training / Post-training |

0-Dまで終わったら、Phase 1の「完全ローカルChat」に進む。

0-Bで最初に触る教材として `HuggingFaceTB/SmolLM3-3B` が選ばれた。
将来の商品に採用するという意味ではなく、教材として都合がよいためである。
理由は次の通りである。

- 3Bなので、4070 12GBなら量子化せずBF16の元の重みを直接扱える。
- Hugging Face自身が公開している。
- Base版とPost-training済みの版の両方がある。
- Apache 2.0である。

0-Dでは、Post-training前の「文章の続きを生成するモデル」であるSmolLM3-3B-Baseと、Post-training済みの「人間の指示に答えるモデル」であるSmolLM3-3Bを同じ4070上で比較する計画である。
なお、会話中の思考メモではSmolLM2 1.7B級から始める案も一度挙がっていたが、提示された計画はSmolLM3-3Bである。

会話終了時点（2026-09-20）の進捗は次の通りである。

- 0-Aの環境構築は完了した。手順は [[LLM Training Environment on WSL2|WSL2でのLLM学習環境構築]] にまとめている。
- 0-Bへ進む前に、Weight、学習、Loss、事前学習と事後学習の違いを、PyTorchの小さなモデルで確認した。内容は [[Neural Network Basics for LLM|LLMを理解するためのニューラルネットワーク基礎]] にまとめている。
- Embeddingの実習コードを受け取ったところで会話は終わっている。その後はAttention、Transformerへ進む予定とされていた。
- 0-B以降の、SmolLM3-3Bを直接ロードする作業はまだ行っていない。

## ブログ化のために残す画面

学習後にブログを書くため、ChatGPTは記事に使えるスクリーンショットの候補を随時示している。
会話中に挙がった候補は次の通りである。

- `wsl -l -v` の画面：Windows上にWSL2環境を用意した説明に使う。
- `nvidia-smi` の画面：RTX 4070、12282 MiB、WSL2が一画面に見え、導入部分に使いやすい。
- `uv init` 後の `ls -la`：学習環境をWindows本体から分離し、専用のPythonプロジェクトを作った説明に使う。
- PyTorchから `CUDA available: True`、GPU名、VRAM 11.99GBが表示された画面：`nvidia-smi` とセットにすると、GPUがOSで認識された段階とPyTorchから計算環境として認識された段階の二段階を説明できる。
- `train_linear.py` の実行結果：学習前のWeight、Lossの減少、学習後のWeight、本当のWeightを一画面に収めると、「機械学習とはWeightを調整すること」を説明する図になる。

## 説明の書き方を途中で揃えた

途中で利用者は、説明文が分かりにくいとして、ChatGPTのプロジェクト内にある二つの文章規範に従うよう指示した。
規範ファイルは `japanese-tech-writing.md` と `cognitive-rhythm-writing.md` である。

ChatGPTはその内容を、技術用語を先に定義する、段落ごとに一つの論点を進める、一文ごとに改行しつつ短文を乱立させない、観察した事実から意味へ進む、説明途中の疑問を置き去りにしない、とまとめている。
以降の説明はこの規範に沿って出し直された。

## 関連

- [[Enterprise Model Distillation|企業向け蒸留モデル]]
- [[Custom Model Business|企業専用モデルの販売事業]]
- [[Enterprise Local AI Assistant|企業向け完全ローカルAIアシスタント]]
- [[LLM Training Environment on WSL2|WSL2でのLLM学習環境構築]]
- [[Neural Network Basics for LLM|LLMを理解するためのニューラルネットワーク基礎]]
- [[On-demand GPU Rental for LLM|必要なときだけGPUを借りてLLMを動かす]]
- [[Reading LLM Benchmarks|LLMベンチマークの読み方]]

## 参考資料

- Hugging Face, *HuggingFaceTB/SmolLM3-3B*
- https://huggingface.co/HuggingFaceTB/SmolLM3-3B
- 原本：[[Sources/Model Distillation/ChatGPT-企業向け蒸留モデル解説-20261001-1717.md]]
#lesson
