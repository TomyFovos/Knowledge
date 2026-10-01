# 読み上げ君：ローカルTTSのChrome拡張

Status: Idea

Chrome上で選択した文章を、事前に作った「好きな声」で読み上げるシンプルなChrome拡張「読み上げ君」の構想と実装計画である。
クラウドの音声合成もサーバーも使わず、事前学習した軽量な声のモデルをブラウザ内のCPUで動かす。
将来は同じ声の資産を使い、2人の掛け合いによるラジオ風MP3をクライアント側で作る構想もある。
TTS、ONNX、OSやクラウドの読み上げとの違いといった一般的な知識は [[Local TTS and ONNX|ローカルTTSとONNX]] に分けた。

元メモの更新日は2026-10-01である。
まだ実装していない計画であり、技術選定は実装時点の調査で確定させる前提になっている。

## 方針は「外へ出さず、普段はGPUを使わない」である

元メモが掲げる重要な方針は次のとおりである。

- クラウドの音声合成（TTS）を使わない。
- 外部APIを使わない。
- 自前サーバーでTTS推論しない。
- ユーザーが選択した文章を外部へ送らない。
- 通常利用時に高負荷なGPU推論を必要としない。
- 好きな声は、事前にGPUを使って学習・変換しておく。
- 読み上げ時は、軽量なローカルモデルをCPUやWebAssembly（WASM）で実行する。
- 最小構成の製品（Minimum Viable Product, MVP）は「選択範囲を右クリックして読む」だけにする。

クラウドの生成TTS（元メモではGemini 3.8 Flash TTSを例に検討）は高品質である。
しかし、API利用が前提で、利用量に応じた費用がかかり、オフラインで使えず、選択文章をクラウドへ送る必要がある。
サービスとして大量に使うと運営コストも増える。
これらが読み上げ君の目的と合わないため、採用しない。

## GPUを使うのは声を作るときだけにする

採用するのは、好きな声を事前に学習し、その声を軽量なローカルTTSモデルとして持つ方式である。

```text
最初だけ
────────────────
音声データ
 ↓
GPUで学習 / 追加学習（Fine-tuning）
 ↓
軽量なVoiceモデルへ変換
 ↓
voice.onnx
voice.onnx.json

普段
────────────────
Chromeで文章を選択
 ↓
右クリック
 ↓
「読み上げ君」
 ↓
ローカルのvoice.onnx
 ↓
CPU / WASMで推論
 ↓
音声再生
```

設計の要点は、GPUを使うのは声を作るときだけ、という点である。
通常利用時は手元のRTX 4070を占有しない。

最高音質は重視しない。
重視するのは、軽い、ローカル、サーバー不要、API不要、好きな声、Chromeで手軽に使える、という条件である。
そのため、巨大な生成TTSを毎回GPUで推論するより、事前学習済みの軽量な声を **ONNX（Open Neural Network Exchange）** とWASMでCPU推論する方が合っている。

## TTSエンジンはPiper Plus系を第一候補にするが固定しない

現時点では、Piper Plus系を第一候補として検討する。
元メモが挙げる理由は次のとおりである。

- 日本語に対応している。
- OpenJTalk等による日本語前処理を利用できる。
- 声の学習や追加学習ができる。
- ONNXへ書き出せる。
- CPU推論に向いている。
- WASMやブラウザで使う実装が存在する。
- 軽量である。
- Chrome拡張との相性が良い。

これらは元メモ時点の認識であり、実装時点で最新状況を確認する。
Piper Plusに無条件で固定しない。

比較するときの基準は、優先順に次のとおりである。

1. 日本語が自然に読める。
2. 独自の声を学習できる。
3. ローカル配布可能な形式へ変換できる。
4. ブラウザ上でCPU推論できる。
5. モデルサイズが小さい。
6. 起動が速い。
7. ライセンスが明確である。
8. 実装がシンプルである。

高品質だが巨大な生成TTSより、十分自然で、とにかく軽いTTSを優先する。

## MVPは「選択文章を固定の声で読む」だけにする

ユーザー体験は次の一つだけである。

```text
Webページ

これは読み上げたい文章です。
^^^^^^^^^^^^^^^^^^^^^^^^
       選択

右クリック

┌──────────────┐
│ 読み上げ君   │
└──────────────┘

 ↓

好きなVoiceで再生
```

MVPでは、次のものを作らない。

- ページ全文の読み上げ。
- 自動スクロール。
- 読み上げ位置のハイライト。
- 複数の声の選択や切り替え画面。
- 声の管理画面。
- ピッチ、音量、速度の調整画面。
- ログイン、アカウント。
- クラウド同期。
- バックエンドサーバー、API、データベース。
- 利用状況の収集（テレメトリ）。
- AIによる本文解析、要約、翻訳。
- MP3保存。
- ラジオ生成。
- Chrome Web Storeへの公開。

## 拡張はService WorkerとOffscreen Documentで構成する

Chrome拡張の新しい仕様である **Manifest V3（MV3）** を使う。

```text
extension/
│
├── manifest.json
├── service-worker.js
│
├── offscreen.html
├── offscreen.js
│
├── tts/
│   ├── runtime
│   ├── phonemizer
│   └── inference
│
└── voice/
    ├── voice.onnx
    └── voice.onnx.json
```

処理の流れは次のとおりである。

```text
service-worker
 ↓
右クリックメニュー処理
 ↓
selectionText取得
 ↓
Offscreen Documentへ渡す
 ↓
日本語前処理
 ↓
ONNX/WASM推論
 ↓
AudioContext
 ↓
音声再生
```

役割を分けると次のようになる。

| 部品 | 役割 |
| --- | --- |
| `service-worker` | `chrome.contextMenus` で右クリックメニューを出し、選択文章を受け取る。 |
| `offscreen.html` / `offscreen.js` | 日本語前処理（G2P）、ONNX / WASM推論、`AudioContext` による再生。 |
| `tts/` | ランタイム、音素変換器（phonemizer）、推論処理。 |
| `voice/` | 声のモデル `voice.onnx` と設定 `voice.onnx.json`。 |

### 右クリックメニューは選択時だけ出す

右クリックメニューは、文章を選択したときだけ表示する。

```text
contexts: ["selection"]
```

Chromeが渡す `selectionText` を使う。
ページ全体を読む必要がないため、不要なDOMの読み取り（スクレイピング）はしない。
可能なら、ページに常駐する **Content Script** も不要にする。

### 音声はOffscreen Documentで生成・再生する

MV3のService Workerは通常のWebページと異なり、`AudioContext` 等の利用に制約がある。
そのため、画面を持たない補助ページである **Offscreen Document**（`chrome.offscreen`）を音声生成・再生用に使う構成を第一候補にする。

```text
Service Worker
 ↓
Offscreen Document
 ↓
TTS推論
 ↓
音声再生
```

### 推論はブラウザ内のCPUとWASMで行う

TTS推論はブラウザ内で行う。
候補は **ONNX Runtime Web** か、Piper Plus側のWASM / ブラウザ用ランタイムである。

```text
CPU + WASM
 ↓
十分速ければ採用
```

WebGPUはMVPでは不要である。
目的はGPU性能を使うことではなく、通常利用時の負荷を小さくすることにある。

外部のコンテンツ配信網（CDN）からJavaScriptやWASMを読み込んで実行する設計にはしない。
必要なコード、WASM、モデルは原則として拡張のパッケージ内に含める。

## 読み上げはオフラインで完結させる

完成した読み上げ機能はオフラインで動くこと。
読み上げ中に、次の宛先へ文章を送信しない。

```text
Google
OpenAI
Microsoft
自前サーバー
CDN
外部TTS API
```

拡張をインストールした後にネットワークを切断しても、次の流れが動くことを目標にする。

```text
選択
 ↓
読み上げ君
 ↓
音声
```

読み上げ時のデータフローは、最終的に次のものだけにする。

```text
Chrome
↓
ローカルWASM/ONNX
↓
CPU
↓
Speaker
```

## 日本語処理はTTSエンジン側の仕組みを使う

日本語TTSでは、読み、音素、アクセント等の処理が必要になる。

```text
日本語文章
 ↓
OpenJTalk等
 ↓
G2P / 音素列
 ↓
TTSモデル
 ↓
音声
```

日本語の文字列を、英語向けの音素変換器へそのまま渡さない。
Piper Plus側の日本語対応（OpenJTalk、**書記素から音素への変換（Grapheme-to-Phoneme, G2P）**、アクセント処理、句読点、数字、英数字混在）を利用する。

最低限、次の文章が破綻せず読めることを確認する。

```text
こんにちは。今日は良い天気ですね。

2026年9月25日です。

RTX 4070を使用します。

AIの進化は非常に速いです。

価格は1,980円です。
```

英数字混在が多少不自然でも、MVPでは許容する。

## 長文は自然な境界で分割して順に再生する

ページ全文の読み上げはしないが、選択範囲に数百〜数千文字が入る可能性はある。
モデルに入力長の制限がある場合は、次のような自然な境界で分割する。

```text
。
！
？
改行
```

分割した塊ごとに、生成して再生する。

```text
chunk 1
 ↓
生成
 ↓
再生

chunk 2
 ↓
生成
 ↓
再生
```

高度な文章解析は不要である。

## 新しい読み上げは現在の再生を止めてから始める

新しい文章で読み上げ君を実行した場合は、現在の読み上げを停止して新しい文章を読む。
複数の音声が重ならないようにする。

## 開発は二段階に分ける

いきなり独自の声の学習とChrome拡張を同時に作らない。
先に既存の日本語の声で、Chrome、WASM、ONNX、日本語TTSという実行経路が成立することを確かめる。

### Phase 1：既存の日本語の声でChrome拡張を完成させる

```text
Chrome
 ↓
選択文章
 ↓
右クリック
 ↓
既存日本語Voice
 ↓
音声
```

ここでは独自の声でなくてよい。

完了条件は次のとおりである。

1. Chromeへ未パッケージ拡張（unpacked extension）として導入できる。
2. 通常のWebページで日本語文章を選択できる。
3. 右クリックメニューに「読み上げ君」が出る。
4. 押すと選択文章が日本語の声で読み上げられる。
5. 外部APIを使っていない。
6. ネットワーク切断状態でも読める。
7. CUDAなしで動く。
8. 読み上げ処理にRTX 4070を必要としない。
9. Chromeを再起動しても動く。
10. 不要な権限を要求しない。

この段階で、次の項目を測定する。

- 初回起動（Cold start）時間。
- 2回目以降の起動（Warm start）時間。
- 1文程度の生成速度。
- CPU使用率。
- メモリ使用量。
- 声のモデルのサイズ。
- 拡張全体のサイズ。

### Phase 2：独自の声を作る

Phase 1が成功した後に、好きな声を学習する。

```text
音声Dataset
 ↓
GPU Fine-tuning
 ↓
checkpoint
 ↓
ONNX export
 ↓
voice.onnx
voice.onnx.json
 ↓
Chrome Extensionへ配置
```

Phase 1が成立する前に、声の学習へ深入りしない。

### 実装順序

```text
1. 技術調査
2. Piper Plus等の既存日本語VoiceをCLIで読む
3. 同じONNX Voiceをブラウザ/WASMで読む
4. Chrome MV3 Extension化
5. 選択範囲 → 右クリック → 読み上げを完成
6. Offline確認
7. 性能測定
8. 独自Voice用Dataset作成工程
9. RTX 4070でFine-tuning
10. ONNX export
11. Chrome側Voiceを独自Voiceへ交換
12. 最終検証
```

## 独自の声は既存モデルの追加学習で作る

ゼロから学習するより、既存の高品質な日本語モデルを追加学習（Fine-tuning）する方式を優先する。
理由は次のとおりである。

- 必要な音声データ量を減らせる。
- RTX 4070 12GBで扱いやすい。
- 学習時間を短縮できる。
- 日本語の発音品質を維持しやすい。

### 学習データは音声と書き起こしだけにする

学習データ（Dataset）の構成例は次のとおりである。

```text
dataset/
├── wav/
│   ├── 000001.wav
│   ├── 000002.wav
│   └── ...
└── metadata.csv
```

`metadata.csv` の代わりにJSONL等でもよい。
ユーザーが用意するものは、できるだけ「音声ファイル」と「その音声の書き起こし」だけにする。

次の項目は未確定であり、採用するTTSの最新仕様に従って確認する。

- 必要な総録音時間。
- 最低限の音声量と推奨音声量。
- サンプルレート。
- モノラルかステレオか。
- 1クリップの長さ。
- ノイズ、無音、音量の扱い。
- 書き起こしの形式。

### 音声の前処理は必要なら自動化する

```text
resample（サンプルレート変換）
mono化
音量正規化
長い無音の処理
フォーマット統一
```

高度な音源分離やAIによるノイズ除去は、MVPでは不要である。

### 学習環境

想定する環境は次のとおりである。

```text
Windows 11
WSL2 Ubuntu
Ryzen 5 5600X
RAM 48GB
RTX 4070 12GB
CUDA
Python
uv
```

RTX 4070 12GBで動くよう、メモリ不足（Out of Memory, OOM）が起きる場合は次を調整する。

- バッチサイズ（batch size）。
- 勾配累積（gradient accumulation）。
- 数値精度（precision）。
- サンプル長（sample length）。

Python環境の管理には、可能なら `uv` を使う。

### 配布する声は推論に必要な最小ファイルだけにする

最終的な声の成果物は、`voice.onnx` と `voice.onnx.json` など、推論に必要な最小ファイルだけにする。
Chrome側で、PyTorch、CUDA、学習途中の保存データ（checkpoint）を必要としない状態にする。

### 声はファイルの入れ替えだけで変えられるようにする

理想は、次のファイルを入れ替えるだけで声を変えられることである。

```text
extension/voice/
├── voice.onnx
└── voice.onnx.json
```

声ごとに拡張のロジックを書き換えない。
MVPでは声の管理画面は作らない。

## 権限は最小にし、ライセンスは部品ごとに確認する

読み上げ対象の文章を外部へ送信しない。
不要なChrome権限も避ける。
例えば次の権限は、必要がなければ付与しない。

```text
history
cookies
webRequest
広範囲なhost_permissions
```

ライセンスは次を別々に確認する。

```text
TTS Engineのライセンス
Base modelのライセンス
Voice datasetのライセンス
Fine-tuning後モデルの扱い
WASM/npm dependencyのライセンス
```

独自の声に使う音声は、本人または利用許諾を得た音声のみとする。
将来サービス化や商用利用をする可能性があるため、配布制限のある依存関係には注意する。

## リポジトリ構成は単純に保つ

```text
yomiage-kun/
│
├── extension/
│   ├── manifest.json
│   ├── service-worker.*
│   ├── offscreen.html
│   ├── offscreen.*
│   ├── tts/
│   └── voice/
│
├── training/
│   ├── scripts/
│   ├── config/
│   └── README.md
│
├── docs/
│   └── architecture.md
│
├── README.md
└── LICENSE
```

過剰なマイクロサービス化や複雑なディレクトリ構造にはしない。

## 将来は声の資産をラジオ生成へ再利用する

読み上げ君で作った声の資産は、将来のラジオ生成サービスにも再利用できる。
これは構想段階であり、MVPの範囲外である。

例えば、2つの声のモデルを持つ。

```text
voice-a.onnx
voice-b.onnx
```

台本の話者ごとに声を割り当てて生成する。

```text
台本

A: 今日紹介するのは生成AIです。

B: 最近かなり進化しましたよね。

A: そうなんです。
```

```text
A → voice-a.onnx
B → voice-b.onnx
```

生成した音声を、無音やBGMとつなげてMP3にする。

```text
音声A
+
無音
+
音声B
+
BGM
 ↓
MP3
```

MP3生成までクライアント側で行えば、サービス提供側はGPUサーバーを持たずに済む。

### 読み上げ君とラジオ生成は声の資産を共有し、出力経路が異なる

```text
                   Voice資産
                 /            \
                /              \
       読み上げ君             ラジオ生成
       Chrome拡張              Web/App
           ↓                     ↓
     リアルタイム再生        WAV/PCM取得
                                 ↓
                              音声合成
                                 ↓
                               MP3
```

声の資産は共通化する。
ただし、Chromeの標準TTS再生APIは音声の生データ（PCM/WAV）の取得に向かない。
そのため、ラジオ生成ではONNX / WASMを直接呼び出して音声バッファを取得する方がよい。

## 実装はAIエージェント「Astra」へ依頼する想定である

元メモは、実装をAIエージェント「Astra」へ依頼する想定で書かれている。
Astraに厳守させる最重要条件は次のとおりである。

```text
シンプル
完全ローカル
サーバー負荷ゼロ
選択範囲だけ
軽量
1 Voice
```

そして必ず次の順で進めさせる。

```text
1. 技術調査
2. 既存日本語VoiceをCLIで読む
3. 同じVoiceをブラウザ/WASMで読む
4. Chrome Extension化
5. 選択範囲 → 右クリック → 読み上げ
6. Offline確認
7. 性能測定
8. 独自Voice Dataset作成
9. RTX 4070でFine-tuning
10. ONNX export
11. Chrome側Voice差し替え
12. 最終検証
```

Phase 1が成功する前に、声の学習へ深入りさせない。
過剰実装を禁じ、作らないものを明示し、完了条件と報告項目を先に決めて渡す点は、[[Spec-Driven Development|仕様駆動開発]] の考え方に近い。

## 現時点の結論

クラウドTTSではなく、次の方式を採用する。

```text
好きな声
 ↓
GPUでFine-tuning
 ↓
軽量Voiceモデル
 ↓
ONNX
 ↓
Chrome + WASM + CPU
```

これにより、次の構成を目指す。

- API料金がかからない。
- 外部サーバーが要らない。
- オフラインで使える。
- プライバシーを確保できる。
- サービス提供側のGPUコストがかからない。
- 将来のラジオ生成にも声を再利用できる。

最初の目標は非常に小さい。
Chromeで文章を選択し、右クリックし、好きな声で読む。
ここを完成させてから、必要に応じてラジオ生成などへ拡張する。

## 実装依頼プロンプト

元メモが「そのままAstraへ渡してよい」としている依頼文である。
成果物なので、原文のまま残す。

````markdown
## 「読み上げ君」Chrome拡張 + ローカル日本語TTS Voice 作成依頼

### 目的

Chrome上でユーザーが選択した日本語テキストを、事前に作成した「好きな声」のローカルTTSモデルを使って読み上げる、非常にシンプルなChrome拡張を作成してください。

このプロジェクトでは、クラウドTTS、外部API、サーバー推論は使用しません。

最終的には、

```text
Webページ上の文章を選択
        ↓
右クリック
        ↓
「読み上げ君」
        ↓
ローカルに保持しているTTS Voiceモデル
        ↓
CPU上で音声生成
        ↓
Chromeから再生
```

という体験だけを実現してください。

重要なのは、

- サーバー負荷ゼロ
- API料金ゼロ
- 読み上げる文章を外部へ送らない
- 読み上げ時にRTX 4070を必要としない
- 一度Voiceモデルを作った後は軽量に利用できる
- Chrome上では「選択範囲を右クリックして読む」だけ

という構成です。

### 最重要方針

過剰実装しないでください。

今回のMVPには以下は不要です。

- ページ全文読み上げ
- 自動スクロール
- 読み上げ位置ハイライト
- 複数Voice切り替えUI
- 音量設定UI
- ピッチ設定UI
- 再生速度設定UI
- ログイン
- アカウント
- クラウド同期
- バックエンドサーバー
- API
- データベース
- テレメトリ
- 利用状況収集
- AIによる本文解析
- 要約
- 翻訳
- MP3保存
- ラジオ生成
- Chrome Web Store公開作業

今回は、

**「選択した文章を、固定された1種類のローカルVoiceで読む」**

だけです。

### 開発環境

```text
Windows 11
WSL2 Ubuntu
CPU: Ryzen 5 5600X
RAM: 48GB
GPU: NVIDIA RTX 4070 12GB
CUDA利用可能
Python / uv 利用可能
Chrome
```

Voiceの学習/Fine-tuning時にはRTX 4070を使用して構いません。

ただし完成したChrome拡張での通常読み上げ時には、CUDA/GPUを必須にしないでください。

基本方針：

```text
Voice作成時
RTX 4070使用可

↓

ONNX等の配布可能な推論モデルへ変換

↓

普段の読み上げ
Chrome + WASM + CPU
```

としてください。

### 技術選定

現時点では第一候補として Piper Plus 系を検討してください。

特に以下を確認してください。

- 日本語対応
- OpenJTalk等による日本語G2P
- Voice学習 / Fine-tuning
- ONNX export
- CPU推論
- WebAssembly
- npm/browser利用
- Chrome Extensionから利用可能か
- ライセンス
- Voiceモデルのライセンス
- 商用利用時の制約

ただし、Piper Plusを無条件で採用しないでください。

実装開始前に、

**「2026年9月現在、今回の用途にPiper Plusが適切か」**

を短時間調査してください。

比較対象があるなら確認してください。ただし大規模な技術調査プロジェクトにはしないでください。

選定基準の優先順位は、

1. 日本語が正常に読める
2. 独自Voiceを学習できる
3. ONNXなどローカル配布可能な形式にできる
4. ブラウザ上でCPU推論できる
5. モデルが比較的小さい
6. 推論開始が速い
7. ライセンス上問題が少ない
8. 実装がシンプル

です。

高品質だが巨大な生成TTSより、

**十分自然で、とにかく軽いTTS**

を優先してください。

### 開発は2段階に分ける

いきなり独自Voiceを学習してChromeまで繋げないでください。

#### Phase 1

既存の日本語Voiceを使ってChrome拡張を完成させる。

まず、

```text
Chrome
↓
選択文章
↓
右クリック
↓
ローカルTTS
↓
音が出る
```

を成立させてください。

ここでは独自Voiceでなくて構いません。

目的は、

**Chrome + WASM + ONNX + 日本語TTS**

というランタイム経路が成立することの確認です。

### Chrome Extension仕様

Manifest V3で作成してください。

ユーザー操作はこれだけです。

```text
Webページ

これは読み上げたい文章です。
^^^^^^^^^^^^^^^^^^^^^^^^
      選択

右クリック

┌──────────────┐
│ 読み上げ君   │
└──────────────┘

↓

音声再生
```

context menuは、

```text
contexts: ["selection"]
```

としてください。

`chrome.contextMenus` から取得できる `selectionText` を利用してください。

不要なDOMスクレイピングは行わないでください。

### 推奨アーキテクチャ

```text
Chrome Extension
│
├─ manifest.json
│
├─ service-worker.js / ts
│      │
│      └─ contextMenus
│
├─ offscreen.html
├─ offscreen.js / ts
│      │
│      ├─ 日本語前処理 / G2P
│      ├─ ONNX / WASM推論
│      └─ AudioContextで再生
│
├─ tts/
│      ├─ runtime
│      ├─ phonemizer
│      └─ inference
│
└─ voice/
       ├─ voice.onnx
       └─ voice.onnx.json
```

Manifest V3ではService WorkerだけでAudioContext等を扱わず、

**Offscreen Document**

を音声生成・再生用として使う方針を検討してください。

### WebAssembly

TTSランタイムはブラウザ内で実行してください。

可能であれば、

```text
ONNX Runtime Web
```

またはPiper Plusが提供するWASM/browser runtimeを利用してください。

外部CDNからJavaScript/WASMを実行する設計にはしないでください。

必要なコード・WASM・モデルは原則としてExtension package内に含めてください。

### ネットワーク禁止

完成した読み上げ機能はオフラインでも動作すること。

読み上げ処理中に、

```text
Google
OpenAI
Microsoft
自前サーバー
CDN
外部TTS API
```

等へテキストを送信してはいけません。

Extensionインストール後にネットワークを切断しても、

```text
選択
↓
読み上げ君
↓
音声
```

が動作することを確認してください。

### 日本語処理

日本語の文字列をそのまま英語向けphonemizer等へ渡さないでください。

Piper Plus側の日本語対応、

```text
OpenJTalk
G2P
アクセント処理
句読点
数字
英数字混在
```

などを利用してください。

最低限、

```text
こんにちは。今日は良い天気ですね。

2026年9月25日です。

RTX 4070を使用します。

AIの進化は非常に速いです。
```

程度の日本語・数字・英数字混在文章が破綻せず読めることを確認してください。

### 長文

MVPではWebページ全文には対応しません。

ただし選択範囲として、数百〜数千文字が来る可能性があります。

モデル側に入力長制限がある場合は、

```text
。
！
？
改行
```

など自然な境界で分割してください。

### 再生制御

新しく別の文章を選択して「読み上げ君」を実行した場合は、

**現在の読み上げを停止して、新しい文章を読む**

挙動を推奨します。

### Phase 1 完了条件

1. Chromeへunpacked extensionとしてインストールできる。
2. 任意の通常Webページで日本語文章を選択できる。
3. 右クリックメニューに「読み上げ君」が表示される。
4. 押すと選択文章が日本語Voiceで読み上げられる。
5. 外部APIを使用していない。
6. ネットワーク切断状態でも読める。
7. CUDAなしでも動く。
8. RTX 4070を読み上げ処理に使用する必要がない。
9. Chromeを再起動しても動く。
10. 不要な権限を要求しない。

この段階で、

- Cold start時間
- Warm start時間
- 1文程度の生成速度
- CPU使用率
- メモリ使用量
- Voiceモデルサイズ
- Extension全体サイズ

を測定してください。

### Phase 2：独自Voice作成

Phase 1が成功したあと、

**自分で権利・利用許諾を持つ音声データ**

から独自Voiceを作る工程を追加してください。

```text
training/
    ↓
音声Dataset
    ↓
GPU Fine-tuning
    ↓
checkpoint
    ↓
ONNX export
    ↓
voice.onnx
voice.onnx.json
    ↓
Chrome Extensionへ配置
```

### 学習方式

可能ならゼロから学習せず、

**既存の高品質な日本語モデルからFine-tuning**

する方針を優先してください。

### Dataset

```text
dataset/
├── wav/
│   ├── 000001.wav
│   ├── 000002.wav
│   └── ...
└── metadata.csv/jsonl
```

のような分かりやすい形式を採用してください。

ユーザーが用意するものはできるだけ、

```text
音声ファイル
+
その音声の文字起こし
```

だけにしてください。

### Fine-tuning

WSL2 + RTX 4070 12GB環境で実行可能な設定を用意してください。

OOMが起きる場合は、

- batch size
- gradient accumulation
- precision
- sample length

等を調整してください。

Python環境管理は可能なら `uv` を使用してください。

### Export

学習後に、

```text
voice.onnx
voice.onnx.json
```

または採用ランタイムに必要な最小限のファイルへ変換してください。

最終的なVoice artifactには、

**PyTorch開発環境やCUDAが不要**

な状態を目指してください。

### Voice差し替え

理想的には、

```text
extension/voice/
├── voice.onnx
└── voice.onnx.json
```

を交換するだけで済む設計にしてください。

### セキュリティ / プライバシー

読み上げ対象テキストを外部へ送らないこと。

不要な権限を要求しないこと。

### ライセンス確認

必ず以下を分けて確認してください。

```text
TTS Engineのライセンス
Base modelのライセンス
Voice datasetのライセンス
学習して生成したVoice modelの扱い
npm/WASM dependencyのライセンス
```

今回使用する独自音声データについては、

**本人または利用許諾を得た音声のみを前提**

とします。

### Repository構成

```text
yomiage-kun/
│
├── extension/
│   ├── manifest.json
│   ├── service-worker.*
│   ├── offscreen.html
│   ├── offscreen.*
│   ├── tts/
│   └── voice/
│
├── training/
│   ├── scripts/
│   ├── config/
│   └── README.md
│
├── docs/
│   └── architecture.md
│
├── README.md
└── LICENSE
```

### 実装順序

```text
1. 技術調査
2. Piper Plus等の既存日本語VoiceをCLIで読む
3. 同じONNX Voiceをブラウザ/WASMで読む
4. Chrome MV3 Extension化
5. 選択範囲 → 右クリック → 読み上げを完成
6. Offline確認
7. 性能測定
8. 独自Voice用Dataset作成工程
9. RTX 4070でFine-tuning
10. ONNX export
11. Chrome側Voiceを独自Voiceへ交換
12. 最終検証
```

Phase 1が成立する前にPhase 2の学習へ深入りしないでください。

### 完成条件

最終的にユーザーが、

```text
1. Chromeで文章を選択する
2. 右クリックする
3. 「読み上げ君」を押す
4. 自分で事前学習したVoiceで音が出る
```

これだけで使える状態にしてください。

読み上げ時のデータフローは、

```text
Chrome
↓
ローカルWASM/ONNX
↓
CPU
↓
Speaker
```

だけにしてください。

外部サーバーは存在させないでください。

### 最後に報告してほしい内容

```text
採用したTTS
採用理由
Voiceモデル形式
Voiceモデルサイズ
Chrome Extensionサイズ
日本語G2P方式
Cold start時間
Warm start時間
CPU使用量
メモリ使用量
GPU使用有無
ネットワーク通信有無
学習に必要だったVRAM
学習Dataset量
独自Voiceの主観的な再現度
判明した制約
今後改善するとしたら何か
```

をまとめてください。

今後の追加機能を勝手に実装せず、まずは

**「選択範囲を好きな声で読む」**

という一点を完成させることを最優先してください。
````

## 関連

- [[Local TTS and ONNX|ローカルTTSとONNX]]
- [[Spec-Driven Development|仕様駆動開発]]
- [[On-demand GPU Rental for LLM|必要なときだけGPUを借りてLLMを動かす]]

## 参考資料

- 原本：[[Sources/Yomiage-kun/yomiage-kun_tts_knowledge.md]]

#lesson
