# agent-desktop ナレッジ

調べた日: 2026-11-02

## 読み方

この文書は次の3種類の内容を書き分けています。

- 確認済み: GitHub の README（調べた日に取得）に書かれていた内容。特に断りがなければこれにあたります
- 一般: README にはなく、一般的な知識として補った内容
- 推測: 会話の中での検討や見込み。実際に試して確かめていません

## 概要

agent-desktop は、Vercel Labs が公開している、デスクトップアプリを AI エージェントに操作させるための CLI と C ライブラリです。画面の画像ではなく、OS のアクセシビリティツリー（画面上の部品を構造として表したもの）を読み、その構造をもとに操作します。Rust 製で、macOS、Windows、Linux に対応し、ライセンスは Apache-2.0 です。調べた時点で GitHub のスターは約 1.9k でした。

要点は次の4つです。

- 画面の構造を JSON で返し、操作できる部品ごとに ref（参照 ID）を付ける
- エージェントは ref を指定して操作し、もう一度 snapshot を取って結果を確かめる
- 何をするかを判断するループはエージェント側にあり、agent-desktop は「見る」と「操作する」の道具だけを提供する
- テスト自動化では既存の E2E ツールを置き換えるより、探索とテスト作成を助ける道具として使うのが現実的と考えられる（推測）

## 理解に必要な前提

### アクセシビリティツリー（一般）

OS はスクリーンリーダーなどの支援技術のために、画面上のボタンや入力欄を、種類（role）、名前、状態を持つ部品の木構造として外部に公開しています。これがアクセシビリティツリーです。部品が公開されていれば、プログラムは見た目ではなくこの構造を読んで操作できます。Windows では UI Automation が代表的な仕組みです。agent-desktop が Windows でどの API を使うかは、README に書かれていませんでした。

### スクリーンショット方式の computer use（一般）

スクリーンショットをモデルに見せ、画面上の座標を推測してクリックする方式があります。画像を入力する必要があり、座標がずれると誤操作になります。agent-desktop はこの方式ではありません。なお、Codex の Computer Use の内部実装は確認していません。

### デスクトップ向けの E2E ツール（一般）

Web は Playwright、Windows のデスクトップアプリは FlaUI、pywinauto、Appium の Windows ドライバーなどで自動化するのが一般的です。いずれも、人が手順をコードで書き、同じ手順を毎回再現するための道具です。

## 解説

### 基本の流れ

見る、操作する、もう一度見て確かめる、の繰り返しです。次は README にある macOS の例です。

```
agent-desktop snapshot --app Finder -i      # 操作できる部品を、ref 付きで取得
agent-desktop click @s8f3k2p9:e8            # snapshot で得た ref を指定して操作
agent-desktop snapshot --app Finder -i      # もう一度取得して結果を確認
```

どのアプリを指定できるかは `agent-desktop list-apps` で調べられます。snapshot はアプリ名、ウィンドウ、snapshot_id、部品の木構造を含む JSON で返ります。

ref の扱いには、次の決まりがあります。

- ref は取得した snapshot に属し、`@s8f3k2p9:e8` のように snapshot の識別子を含む形で書く。`@e8` のように識別子を省くと `INVALID_ARGS` で拒否される
- 画面が変わると、操作は `STALE_REF` か `AMBIGUOUS_TARGET` を返す。その場合は snapshot を取り直し、新しい ref を使う
- ウィンドウが複数あると `AMBIGUOUS_TARGET` になる。候補のウィンドウ ID は `error.details` に入り、`--window-id` で指定する
- PowerShell では ref を引用符で囲む。`@` で始まる語は展開の演算子（スプラッティング）として扱われるため

### 結果の形と再試行

すべてのコマンドは `ok` と、`data` か `error` を持つ JSON を1つ出力します。`error` にはコード、対処の区分（disposition）、たいてい `suggestion` が入ります。再試行してよいのは、`error.disposition.retry` が `safe` のときだけです。

### 大きなアプリの扱い

部品の多いアプリでは、先に `snapshot --skeleton --app Slack -i --compact` で全体の地図だけを取ります。そのあと、`snapshot --root @s8f3k2p9:e3 -i --compact` で必要な領域だけを詳しく取ります。`-i` は操作できる部品だけに絞るオプションです。

### 動作の既定と権限

- 既定はヘッドレスで、ref を使う操作はアクセシビリティ API を通して行い、ポインタを動かさず、フォーカスも奪わない
- `--headed` を付けると、物理的な入力を許可する
- macOS はアクセシビリティの許可が必要で、`agent-desktop permissions --guide` で手順を確認できる
- Windows は、端末と同じ整合性レベルのアプリなら許可は不要
- Linux はグラフィカルセッションと `at-spi2-core` が必要

macOS では snapshot の名前空間ごとにコマンドのホストプロセスを再利用し、アイドル状態が15分続くと終了します。ホストはネイティブのアクセシビリティオブジェクトを保持するため、消えた行が、同じ識別子を持つ別の行に気づかないうちに割り当てられるのを防ぎます。

### コマンドの種類

README では、コマンド名が60個、実際に動くものが56個とされています。`key-down`、`key-up`、`mouse-down`、`mouse-up` の4つは、押したままのキーやボタンを解放する常駐プロセスができるまで、実行を拒否します。

| 分類 | 主なコマンド |
|---|---|
| 観察 | `snapshot`、`find`、`get`、`is`、`screenshot`、`list-surfaces` |
| ref への操作 | `click`、`double-click`、`right-click`、`type`、`set-value`、`clear`、`select`、`toggle`、`check`、`expand`、`scroll` など |
| キーボードとマウス | `press`、`hover`、`drag`、`mouse-move`、`mouse-click`、`mouse-wheel` など |
| アプリとウィンドウ | `launch`、`close-app`、`list-apps`、`list-windows`、`focus-window`、`resize-window`、`minimize` など |
| 通知 | `list-notifications`、`dismiss-notification`、`notification-action` など |
| クリップボード | `clipboard-get`、`clipboard-set`、`clipboard-clear` |
| 待機 | `wait` |
| セッション | `session`、`trace`、`cursor-overlay` |
| システム | `status`、`permissions`、`version`、`batch`、`skills` |

### 組み込み方

- CLI は `npm install -g agent-desktop` で入れる。ネイティブのバイナリを含み、x64 と ARM64 に対応する
- 各リリースには `libagent_desktop_ffi` も含まれ、CLI を起動せずにプロセス内から呼べる
- エージェントには `agent-desktop skills get desktop` と `agent-desktop skills get platform` を最初に読ませる使い方が想定されている。`AGENTS.md` に、この2つを読んで従うよう書いておく方法が README に載っている
- スキルは `npx skills add https://github.com/vercel-labs/agent-desktop --skill agent-desktop` で入れられる

### 扱う情報とプライバシー

snapshot、クリップボードの内容、スクリーンショット、コマンドの出力、デバッグ用の成果物には、画面上の私的な内容が含まれることがあります。公開のログやアップロードには含めないでください。任意の補助機能である JEV ヘルパーは、画面の説明を設定したモデル提供元へ送信します。これはネイティブの CLI とは別の機能です。

## テスト自動化での使い方（推測）

README にテスト自動化の記述はありません。ここは、会話での検討をまとめたものです。

### 基本の考え方

LLM が毎回操作する構成は、実行が遅く、結果も毎回揺れます。そのため、agent-desktop と LLM は探索とテスト作成に使い、毎回の回帰テストは LLM を使わない既存ツールのスクリプトで回す分担が現実的です。

```mermaid
flowchart LR
  A[改修内容を伝える] --> B[コーディングエージェント]
  B -->|snapshot と操作と確認| C[agent-desktop]
  C --> D[対象のアプリ]
  B -->|確認できた手順を書き出す| E[テストスクリプト]
  E --> F[CI で LLM なしに実行]
```

### 役割分担

| 担当 | 役割 |
|---|---|
| agent-desktop と LLM | 未知の画面の探索、シナリオの初稿作成、スクリプト化しにくい操作の確認 |
| 既存ツール（FlaUI、pywinauto、Appium など） | 毎回同じ結果の回帰テスト、CI での高速で安定した実行、値や状態の厳密な検証 |
| Playwright | Web 画面のテスト。役割は変えない |

どちらの方式も、対象アプリが UI の部品を外部に公開していることが前提です。

### 改修に伴うテスト作成の流れ

1. 改修した内容を、コーディングエージェントに伝えてテストを書くよう指示する
2. エージェントが agent-desktop で改修後の画面を開き、snapshot で部品を読み、操作して、`get` や `is` で結果を確かめる
3. 確認できた手順を、既存ツールのテストスクリプトとして書く
4. 書いたスクリプトを、CI などで LLM なしに実行する

スクリプトを書くのはエージェントです。agent-desktop にテストスクリプトを自動生成する機能はありません。動いている画面で部品の名前や挙動を確かめながら書けるため、ソースコードだけを読んで推測で書くより、実際に動くテストになりやすいと考えられます。

### 速さの考え方

遅さが影響する段階は、次のように分けて考えます。

| 段階 | 遅さの影響 |
|---|---|
| 探索とシナリオ作成 | 一度きりのコスト。LLM の待ち時間が支配的で、テスト実行速度には影響しない |
| 手順をスクリプトに変換する部分 | 一度きりのコスト。シナリオを作るときだけかかる |
| CI での実行 | 毎回かかる。テストの速さを決めるのはここだけ |

LLM を実行時に使わなければ、毎回の実行時間を左右するのは既存ツール側の速さです。ただし、変換の手間が大きいと、シナリオを増やす速度が落ちます。

つなぎの部分を軽くする方法は、次のとおりです。

- LLM に既存ツールのコードを直接書かせる。snapshot の role と name を、UI Automation の ControlType や Name に対応づけられる見込みがある（推測）
- 「操作・対象・期待値」の JSON か YAML を中間形式として決め、薄い実行器で回す
- `trace` と `session` で操作を記録できる可能性がある。記録の中身は確認できていない

実行時の速度を上げる方法は、次のとおりです（一般）。

- 要素の特定は名前や階層の検索より AutomationId を優先する
- 固定の待ち時間（sleep）をやめ、条件付きの待機に置き換える
- テストに必要な状態は、UI 操作ではなく API、DB、起動時の引数、設定ファイルで作り、UI を通すのは検証したい操作だけにする
- 使い回せるテストはアプリを起動し直さず同じプロセスで続ける
- 複数のマシンで並列に実行する

agent-desktop を実行時にも使う場合は、`batch` で複数の操作をまとめるか、C ライブラリでプロセス内から呼ぶと、コマンドごとのプロセス起動を避けられます。snapshot は操作のたびに取る必要はなく、検証したい箇所だけで足ります。`find` や `snapshot --root` で範囲を絞れます。Windows での実測値は README にありません。

通常は LLM なしのスクリプトで回し、失敗したときだけ LLM を呼んで原因を調べ、修正案を出させる設計が、最も効果が見込めると考えられます（推測）。UI の変更でスクリプトが動かなくなったときの保守を LLM に任せつつ、毎回の実行は速く保てます。

### モデルの選び方

snapshot は JSON のテキストなので、画像を扱えないモデルでも動かせる見込みがあります（推測）。安価で速いモデルとの相性は良いと考えられます。必要なのは、シェルコマンドを正しく呼ぶ力、JSON を読む力、「snapshot、操作、再 snapshot で確認」の流れを守る力です。小さなモデルは長い手順の途中で迷うことや、`STALE_REF` が出たときの取り直しが苦手になりやすいと考えられます。まず短いシナリオで試すのが安全です。

### 対象アプリによる制約

Windows の WPF、WinForms、標準的な Win32 のコントロールは、部品を取れる可能性が高いと考えられます（一般）。独自描画のアプリ、ゲーム、一部の Qt や Java Swing、設定によっては Electron では、部品が取れない、または名前がなくて特定できないことがあります。管理者権限で動くアプリは、操作する側の権限によって見えない可能性があります。

## 似たものとの違い

| 比べるもの | agent-desktop との違い |
|---|---|
| スクリーンショット方式の computer use（一般） | 画像と座標ではなく、部品の構造と ref で操作する。入力がテキストなので、画像を扱えないモデルでも使える見込みがある（推測） |
| 既存のデスクトップ E2E ツール | 人が手順をコードで書く道具。agent-desktop は、エージェントが画面を見ながら操作する道具で、テストスクリプトは自動生成しない |
| Playwright | Web 専用。agent-desktop は OS のアクセシビリティを使い、アプリを選ばない |

## 会話でわかったこと

### agent-desktop の位置づけ

- agent-desktop は Codex の Computer Use を使うものではなく、独立した道具である。README には Codex が agent-desktop を使う動画があり、エージェントが道具として呼ぶ使い方が想定されている
- 実際の操作は、OS ごとのアダプタが担当する。アダプタは OS ごとに別のクレートで、自分の OS 上でしかビルドできない。Rust 製であることが、そのまま Windows 対応を意味するわけではない

### トークンと速度の工夫

README から確認できた工夫は、次のとおりです。

- 出力が画像ではなくテキストの JSON である
- `-i` で操作できる部品だけに絞り、`--compact` で出力を短くできる
- `--skeleton` で全体の地図だけを取り、`--root` で必要な領域だけを詳しく取れる
- ref が `@s8f3k2p9:e8` のような短い ID である
- ネイティブの Rust バイナリで、ヘッドレスが既定である
- `batch` で複数の操作をまとめられ、C ライブラリならプロセス起動を省ける
- macOS ではホストプロセスを再利用する

トークン削減率や速度の実測値は、README では確認できませんでした。

### テスト自動化への適用

- 改修に伴ってエージェントにテストを書かせる場面で使える。スクリプトを書くのはエージェントで、agent-desktop は画面を見て操作する道具である
- 遅さは段階ごとに分けて考える。LLM を実行時に使わなければ、探索と変換の遅さは毎回の実行時間に入らない
- 最初の確認は対象アプリに対する `agent-desktop snapshot --app <アプリ名> -i` である。部品に名前が付いて出れば有望で、ほとんど空なら難しい

## 未解決事項

- Windows でどの OS の API を使うか、どの種類のアプリまで部品を取れるか。README には書かれていない
- トークン削減率や速度の実測値。リポジトリには `benchmarks/locator-resolution` があるが、中身は読んでいない
- `trace` と `session` の記録の形式と、テストスクリプトへの書き出しに使えるか
- スクリプト側で ref を固定せず、毎回 `find` で部品を探す場合の細かい仕様
- 画像を扱えない小さなモデルで、一連の流れがどこまで安定するか
- 実際のアプリで snapshot を取ったときの結果

## 参考資料

- GitHub: vercel-labs/agent-desktop（2026-11-02 に README を確認）: https://github.com/vercel-labs/agent-desktop
- 製品ページ（README の About に記載。未確認）: https://agent-browser.dev/desktop
- リポジトリ内の文書（README からリンクされているが未読）: `docs/install.md`、`docs/json-output.md`、`docs/faq.md`、`CONCEPTS.md`
- 同梱のドキュメント: `agent-desktop skills get desktop`、`agent-desktop skills get platform`（未実行）

## 更新履歴

| 日付 | 内容 |
|---|---|
| 2026-11-02 | 初版 |
