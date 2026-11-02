---
type: Reference
status: Researching
topics: [RustXNG, SearXNG, メタ検索, 組織内検索]
follow_up: true
follow_up_type: research
created: "2026-11-02"
updated: "2026-11-02"
---

# RustXNGによるメタ検索と組織内検索

RustXNGは、自分ではWeb索引を作らず、複数の検索サイトへ問い合わせて重複排除・順位付けした結果を返すメタ検索エンジンとして紹介される。SearXNGとの互換を目指すRust製の実装である。

根拠は2026-11-02のREADME・リリース調査資料。今回の起動・検索・コード確認は行っていない。互換性文書の一部は原資料でも未取得である。

## 問い合わせ先と検索できる範囲

```text
検索語・エンジン指定 → 対応サイトへ並行問い合わせ
                  → URL重複排除・順位付け → 画面 / JSON / CSV / RSS
```

資料の226エンジン移植済みという数は、移植元の対応単位の数であり、Web全体の網羅率を意味しない。新しい・小さい・有料・非公開のページへの到達は、接続先と権限に依存する。

API・検索構文・設定等の互換性が紹介される一方、テーマ、翻訳数、プラグインには差があり、動的な外部結果の完全一致は保証されない。

## 軽量化とプライバシー

資料は単一バイナリ、起動0.03秒、メモリ13MiB、温まった条件の検索0.28秒等を紹介する。README・リリース側の測定で、キャッシュや一時除外の条件を外した普遍的な検索速度ではない。全体時間は外部サイトの応答・timeoutにも左右される。

画像・faviconの代理取得で利用者IPを隠す説明があるが、検索語は外部エンジンへ送られる。追跡表示がないことと、問い合わせ内容がどこにも送信されないことは別である。

## 組織内検索に使う場合

PostgreSQL、SQLite、Elasticsearch、Meilisearch等を接続先にする構成が資料に挙がる。外部エンジンを無効化し、内部データ源だけに絞る設定は検討できる。

ファイルサーバー・SharePointから索引への取り込みはRustXNG自体の機能として確認されず、外側で用意する構成案である。利用者別の閲覧権限を検索へ反映できるかも未確認で、単に内部索引を接続しただけで権限分離が完成するとはしない。

## 成熟度と未確認

資料では2026-10-18初公開、v0.4.1は10月26日、個人開発の公開初期段階、AGPL-3.0-or-laterと記録する。上流エンジン追加への追従、独自サイト拡張方針、`PORTING.md`・`COMPATIBILITY.md`の内容は未確認。

## 関連・参考資料

- [[Parallel Decisions APIによるWeb根拠付きの型付き判断]]
- [[Treg Web AccessによるSEOエージェントの情報取得改善]]
- [[Microsoft Web IQとWork IQの役割と接続条件]]
- 原本：[[Sources/Knowledge Batch 20261102/RustXNGのメタ検索と社内検索の元資料]]。
- 元ファイル：`RustXNG-Knowledge-20261102.md`。
- 提供資料の参照先：[RustXNG](https://github.com/sahenjp/RustXNG)、[リリース](https://github.com/sahenjp/RustXNG/releases)。
