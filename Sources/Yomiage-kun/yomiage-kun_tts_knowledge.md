# 読み上げ君：ローカルTTS + Chrome拡張 構想・実装ナレッジ

更新日: 2026-10-01

---

## 1. このナレッジの目的

Chrome上で選択した文章を、事前に作成した「好きな声」で読み上げるシンプルなChrome拡張「読み上げ君」を作る。

重要な方針は以下。

- クラウドTTSを使わない
- 外部APIを使わない
- 自前サーバーでTTS推論しない
- ユーザーが選択した文章を外部へ送らない
- 通常利用時に高負荷なGPU推論を必要としない
- 好きな声は事前にGPUを使って学習・変換しておく
- 読み上げ時は軽量なローカルモデルをCPU / WASM等で実行する
- MVPは「選択範囲を右クリックして読む」だけにする

将来的には、同じVoiceモデルを使って2人分の音声を生成し、ラジオ・Podcast風MP3をクライアント側で作る仕組みにも発展させる。

---

# 2. TTSとは

TTSは **Text-to-Speech** の略で、文章を音声へ変換する技術。

```text
文章
 ↓
TTS
 ↓
音声
```

関連する用語は以下。

```text
LLM
文章 → 文章

TTS
文章 → 音声

STT / ASR
音声 → 文章
```

従来のOS標準読み上げと、最近の生成AI系TTSは同じ「TTS」でも性質がかなり異なる。

---

# 3. OSやブラウザの読み上げはどう動いているか

翻訳サービスやブラウザの読み上げ機能では、必ずしも巨大な生成AIモデルを動かしているわけではない。

一般的には以下のような仕組みが使われる。

```text
Webアプリ
 ↓
ブラウザのSpeech API
 ↓
OSのTTS機能
 ↓
音声再生
```

WindowsではSAPI系のTTSが古くから存在し、ChromeなどもOS側のVoiceを利用できる。

Web上では例えば以下のようなAPIで読み上げられる。

```javascript
const utterance = new SpeechSynthesisUtterance("こんにちは");
utterance.lang = "ja-JP";
speechSynthesis.speak(utterance);
```

この方式は非常に軽い。

ただし、標準のWeb Speech APIは基本的に「再生する」ための仕組みであり、生成されたPCM/WAVデータそのものを自由に取得してMP3化する用途には向かない。

---

# 4. Gemini 3.8 Flash TTSとの違い

議論中、一度「Gemini 3.8 Flash TTSがローカルモデルなのでは」という混同があった。

整理すると、Google公式のGemini 3.8 Flash TTSはクラウドサービス側で動作するTTSであり、ローカルで自由に回せるONNX/GGUFモデルとして配布されるものではない。

概念的には以下。

```text
文章
 ↓
Gemini API
 ↓
Google側のTTSモデル
 ↓
音声
```

利点:

- 高品質
- 自然なイントネーション
- 表現力が高い
- Voice設計・Voice Replicationなど高度な機能

欠点:

- API利用が前提
- 利用量に応じてコストが発生
- オフライン利用できない
- 選択文章をクラウドへ送る必要がある
- サービスとして大量利用すると運営コストが増える

今回の「読み上げ君」では、これらが目的と合わない。

---

# 5. 採用する基本方針

今回採用したいのは、

**好きな声を事前に学習し、そのVoiceを軽量なローカルTTSモデルとして持つ方式**

である。

イメージ:

```text
最初だけ
────────────────

音声データ
 ↓
GPUで学習 / Fine-tuning
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

ポイントは、

**GPUを使うのはVoiceを作るときだけ**

という設計。

通常利用時はRTX 4070を占有しない。

---

# 6. ONNXとは

ONNXは、学習済みAIモデルを様々な実行環境で動かしやすくするためのモデル形式。

今回の用途では、

```text
PyTorch等で学習
 ↓
ONNXへ変換
 ↓
Chrome / WASM / CPUで推論
```

という使い方を想定する。

Voiceモデルを、

```text
voice.onnx
voice.onnx.json
```

のようなファイルとして持てれば、学習環境と利用環境を分離できる。

---

# 7. なぜONNX方式が読み上げ君に向いているか

今回重視しているのは最高音質ではなく、

- 軽い
- ローカル
- サーバー不要
- API不要
- 好きなVoice
- Chromeで手軽に使える

という条件。

そのため、

```text
巨大な生成TTS
 ↓
毎回GPU推論
```

より、

```text
事前学習済みの軽量Voice
 ↓
ONNX / WASM
 ↓
CPU推論
```

の方が合っている。

---

# 8. 第一候補：Piper Plus系

現時点では、Piper Plus系を第一候補として検討する。

理由:

- 日本語対応がある
- OpenJTalk等による日本語前処理を利用できる
- Voiceの学習 / Fine-tuningが可能
- ONNXへexportできる
- CPU推論に向いている
- WASM / browser利用の実装が存在する
- 軽量
- Chrome拡張との相性が良い

ただし、実装時点で最新状況を確認し、Piper Plusに無条件固定しない。

比較基準:

1. 日本語が自然に読める
2. 独自Voiceを学習できる
3. ローカル配布可能な形式へ変換できる
4. ブラウザ上でCPU推論できる
5. モデルサイズが小さい
6. 起動が速い
7. ライセンスが明確
8. 実装がシンプル

---

# 9. 読み上げ君 MVP

MVPでは機能を極端に絞る。

## ユーザー体験

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

これだけ。

---

# 10. MVPでやらないこと

以下は実装しない。

- ページ全文読み上げ
- 自動スクロール
- 読み上げ位置ハイライト
- 複数Voice選択
- Voice管理画面
- ピッチ調整UI
- 音量調整UI
- 速度調整UI
- ログイン
- アカウント
- クラウド同期
- バックエンドサーバー
- データベース
- テレメトリ
- 要約
- 翻訳
- MP3保存
- ラジオ生成
- Chrome Web Store公開

MVPは、

**「選択文章を固定Voiceで読む」**

のみ。

---

# 11. 推奨Chrome Extension構成

Manifest V3を使用。

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

役割:

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

---

# 12. Chrome側の処理

context menuは選択時だけ表示する。

```text
contexts: ["selection"]
```

Chromeから取得できる `selectionText` を使用する。

ページ全体を読む必要がないため、不要なDOMスクレイピングは行わない。

可能なら常駐Content Scriptも不要にする。

---

# 13. Offscreen Document

Manifest V3のService Workerは通常のWebページと異なり、AudioContext等の利用に制約がある。

そのため、

```text
Service Worker
 ↓
Offscreen Document
 ↓
TTS推論
 ↓
音声再生
```

という構成を第一候補にする。

音声再生用途として `chrome.offscreen` を使用する。

---

# 14. WebAssembly / ONNX Runtime

TTS推論はブラウザ内で行う。

候補:

- ONNX Runtime Web
- Piper Plus側のWASM/browser runtime

優先順位:

```text
CPU + WASM
 ↓
十分速ければ採用
```

WebGPUはMVPでは不要。

目的はGPU性能を使うことではなく、

**通常利用時の負荷を小さくすること**

である。

---

# 15. ネットワーク要件

完成した読み上げ機能はオフラインで動くこと。

読み上げ中に以下へ送信しない。

```text
Google
OpenAI
Microsoft
自前サーバー
CDN
外部TTS API
```

Chrome拡張インストール後にネットワークを切断しても、

```text
選択
 ↓
読み上げ君
 ↓
音声
```

が動くことを目標とする。

---

# 16. 日本語処理

日本語TTSでは、単純に文字列をモデルへ入れるだけではなく、読み・音素・アクセント等の処理が必要になる。

想定:

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

最低限以下が読めること。

```text
こんにちは。今日は良い天気ですね。

2026年9月25日です。

RTX 4070を使用します。

AIの進化は非常に速いです。

価格は1,980円です。
```

英数字混在は多少不自然でもMVPでは許容。

---

# 17. 長文対応

ページ全文読み上げはしないが、選択範囲に数百〜数千文字が入る可能性はある。

モデル入力制限がある場合は、

```text
。
！
？
改行
```

など自然な境界で分割する。

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

高度な文章解析は不要。

---

# 18. 再生制御

新しい文章を読み上げた場合、

**現在の読み上げを停止して、新しい文章を読む**

挙動にする。

複数の音声が重ならないようにする。

---

# 19. 開発を2段階に分ける

重要。

いきなり独自Voice学習とChrome拡張を同時に作らない。

---

## Phase 1：既存日本語VoiceでChrome拡張を完成

まず、

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

を成立させる。

確認事項:

1. Chromeへunpacked extensionとして導入できる
2. 日本語文章を選択できる
3. 「読み上げ君」が右クリックに出る
4. 選択文章を読み上げられる
5. 外部APIを使っていない
6. オフラインでも動く
7. CUDA不要
8. RTX 4070不要
9. Chrome再起動後も動く
10. 不要な権限がない

測定:

- Cold start時間
- Warm start時間
- CPU使用率
- メモリ使用量
- Voiceモデルサイズ
- Extension全体サイズ

---

## Phase 2：独自Voice作成

Phase 1成功後に、好きな声を学習する。

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

---

# 20. 独自Voiceの学習

ゼロから学習するより、

**既存の高品質な日本語モデルをFine-tuning**

する方式を優先する。

理由:

- 必要な音声データ量を減らせる
- RTX 4070 12GBで扱いやすい
- 学習時間を短縮できる
- 日本語発音品質を維持しやすい

---

# 21. Dataset構成

例:

```text
dataset/
├── wav/
│   ├── 000001.wav
│   ├── 000002.wav
│   └── ...
└── metadata.csv
```

またはJSONL等。

ユーザーが用意するものをできるだけ、

```text
音声ファイル
+
その音声の文字起こし
```

だけにする。

確認すべき項目:

- 必要な総録音時間
- 最低音声量
- 推奨音声量
- サンプルレート
- mono / stereo
- 1クリップの長さ
- ノイズ
- 無音
- 音量
- 書き起こし形式

これらは採用するTTSの最新仕様に従う。

---

# 22. 音声前処理

必要であれば自動化する。

```text
resample
mono化
音量正規化
長い無音の処理
フォーマット統一
```

高度な音源分離やAIノイズ除去はMVPでは不要。

---

# 23. 学習環境

想定環境:

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

RTX 4070 12GBで実行できるよう、

- batch size
- gradient accumulation
- precision
- sample length

を調整する。

---

# 24. Voice artifact

最終的なVoiceは、

```text
voice.onnx
voice.onnx.json
```

など、推論に必要な最小ファイルだけにする。

Chrome側で、

```text
PyTorch
CUDA
学習checkpoint
```

を必要としない状態にする。

---

# 25. Voice差し替え

理想は、

```text
extension/voice/
├── voice.onnx
└── voice.onnx.json
```

を入れ替えるだけでVoice変更可能にすること。

Voiceごとに拡張ロジックを書き換えない。

MVPではVoice管理UIは作らない。

---

# 26. セキュリティ・プライバシー

読み上げ対象テキストを外部送信しない。

不要なChrome権限も避ける。

例:

```text
history
cookies
webRequest
広範囲なhost_permissions
```

は必要がなければ付与しない。

---

# 27. ライセンス確認

以下を別々に確認する。

```text
TTS Engineのライセンス
Base modelのライセンス
Voice datasetのライセンス
Fine-tuning後モデルの扱い
WASM/npm dependencyのライセンス
```

独自Voice用音声は、

**本人または利用許諾を得た音声のみを使用する。**

将来的にサービス化・商用利用する可能性があるため、配布制限のある依存関係には注意する。

---

# 28. 推奨Repository構成

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

---

# 29. 将来構想：ラジオ生成

読み上げ君で作ったVoice資産は、将来のラジオ生成サービスにも再利用できる。

例えば、

```text
voice-a.onnx
voice-b.onnx
```

を持つ。

```text
台本

A: 今日紹介するのは生成AIです。

B: 最近かなり進化しましたよね。

A: そうなんです。
```

を、

```text
A → voice-a.onnx
B → voice-b.onnx
```

で生成する。

その後、

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

にする。

MP3生成までクライアント側で行えば、サービス提供側はGPUサーバーを持たずに済む。

---

# 30. 読み上げ君とラジオ生成の役割分担

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

Voice資産は共通化する。

ただし、Chromeの標準TTS再生APIはPCM/WAV取得に向かないため、ラジオ生成では直接ONNX/WASMを呼び出して音声バッファを取得する方が良い。

---

# 31. Astraに依頼する際の最重要条件

Astraには以下を厳守させる。

```text
シンプル
完全ローカル
サーバー負荷ゼロ
選択範囲だけ
軽量
1 Voice
```

そして必ず、

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

の順で進める。

Phase 1成功前にVoice学習へ深入りしない。

---

# 32. Astra向け実装依頼プロンプト

以下をそのままAstraへ渡してよい。

---

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

---

# 33. 現時点の結論

今回の読み上げ君では、

```text
クラウドTTS
```

ではなく、

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

という方式を採用する。

これにより、

- API料金なし
- 外部サーバー不要
- オフライン利用可能
- プライバシー確保
- サービス提供側のGPUコストなし
- 将来のラジオ生成にもVoiceを再利用可能

という構成を実現する。

最初の目標は非常に小さい。

**Chromeで文章を選択 → 右クリック → 好きな声で読む。**

ここを完成させてから、必要に応じてラジオ生成などへ拡張する。
