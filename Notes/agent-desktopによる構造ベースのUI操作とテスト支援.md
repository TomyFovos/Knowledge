---
type: Reference
status: Researching
topics: [agent-desktop, デスクトップ操作, アクセシビリティ, テスト支援]
follow_up: true
follow_up_type: research
created: "2026-11-02"
updated: "2026-11-02"
---

# agent-desktopによる構造ベースのUI操作とテスト支援

Vercel Labsのagent-desktopは、OSのアクセシビリティツリーを取得し、部品の参照IDで操作するCLI・Cライブラリとして紹介される。判断ループは外側のエージェントが担い、道具側は観察と操作を提供する。

根拠は2026-11-02のREADME調査資料で、一般知識とテスト応用の推測を含む。今回の取り込みではインストール、画面操作、同梱Skillの実行は行っていない。

## snapshotとrefの契約

```text
snapshotで部品とref取得 → refで操作 → 再観察して結果確認
```

refは`@snapshot_id:element_id`のようにsnapshotへ束縛される。資料ではsnapshot IDを省くと`INVALID_ARGS`、古い参照は`STALE_REF`等、複数候補は`AMBIGUOUS_TARGET`として再取得やwindow指定を求める。

結果は`ok`と`data`または`error`のJSON。自動再試行は`error.disposition.retry`が`safe`の場合だけ、とREADMEの契約が説明される。PowerShellでは`@`から始まるrefを引用符で囲む例がある。

大きな画面は`--skeleton`で概観、`--root`で必要領域、`-i`で操作対象、`--compact`で短縮する。古いrefを固定して長期テストの識別子にするのとは違う。

## 実行形態と対象の制限

資料ではRust製、macOS / Windows / Linux、Apache-2.0、既定はアクセシビリティ操作でポインターやフォーカスを奪わないとされる。`--headed`は物理入力を許可する経路になる。

OSごとの権限・実行セッション・アプリ側の公開状況が前提であり、任意のアプリを必ず操作できるとはしない。Windowsの使用API、独自描画や各フレームワークとの実適合性は未確認である。

CLIのほかFFIによるプロセス内呼び出し、`batch`、macOSでのホスト再利用が記載される。60のコマンド名のうち4つの押下保持操作は未実装のため拒否、と資料は報告する。実測の速度・トークン削減率は確認されていない。

## テスト自動化への応用は会話での提案

1. LLMとagent-desktopで未知の画面を探索し、操作・結果を確認する。
2. Agentが確認した手順をFlaUI、pywinauto等のテストへ書き出す。
3. 通常の回帰テストはLLMを介さず実行し、失敗調査や保守にLLMを使う。

agent-desktop自体がテストコードを自動生成する機能ではない。探索・変換の費用と、毎回のCI実行時間を分けて比較する。中間JSON / YAML、traceの流用、小型テキストモデルでの安定性は未検証案である。

snapshot、スクリーンショット、クリップボード等は私的な画面情報を含みうる。資料の任意JEVヘルパーは設定先モデルへ画面説明を送る別機能とされ、ネイティブCLIと区別する。

## 関連・参考資料

- [[エージェント時代のCI高速化と検証範囲の管理]]
- [[AI開発をコーディングから工程管理へ広げる]]
- 原本：[[Sources/Knowledge Batch 20261102/agent-desktopの構造ベースUI操作の元資料]]。
- 元ファイル：`agent-desktop-Knowledge-20261102.md`。
- 提供資料の参照先：[vercel-labs/agent-desktop](https://github.com/vercel-labs/agent-desktop)。
