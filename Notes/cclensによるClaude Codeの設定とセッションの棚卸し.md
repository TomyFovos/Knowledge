---
type: Reference
status: Researching
topics:
  - cclens
  - Claude Code
  - セッション分析
  - Context費用
  - 設定最適化
follow_up: true
follow_up_type: research
created: "2026-11-02"
updated: "2026-11-02"
---

# cclensによるClaude Codeの設定とセッションの棚卸し

cclensは、Claude Codeが通常利用で残すトランスクリプトと設定を解析し、未使用設定、常時Context、ツール失敗、反復編集等を調べるCLIとして紹介される。計測用タスクを追加実行するのではなく、蓄積した記録から棚卸しする方式である。

根拠は2026-11-02の提供資料で、主な情報源は2026-08-05公開の作者Alisue氏の記事。原資料ではRepository・詳細仕様は未確認であり、今回も導入・解析・`optimize`は実行していない。

## catalogとusageを突き合わせる

```text
catalog：設定surfaceの一覧・静的コスト
                         ＼
                           join → 未使用・高負担の候補
                         ／
usage：使用event・時間・Context増分
```

使われた回数の集計だけでは、一度も使われていない設定は現れない。設定一覧を結合することで、「あるのに記録上使われていない」ことを見つける。

ただし、未使用は解析したログ・期間・イベント定義の範囲での判断である。呼び出し記録がないことを、暗黙のルールも含めて完全に無効果・不要と証明したことにはしない。棚卸しの候補と、変更の因果効果を測るA/B評価を分ける。

## 主な表示

| コマンド | 資料で説明される用途 |
|---|---|
| `doctor` | 全体の問題をglobal / project別に示す入口 |
| `inventory` / `usage` | 設定一覧と利用、スキル呼び出し等 |
| `overhead` | 常時オンContextの床値と設定由来部分 |
| `waste` | 静的負担と利用から最適化候補を順位付け |
| `failures` / `stuck` | ツール失敗・反復編集の切り分け |
| `prompts` | 利用者の指示傾向 |
| `sql` | 解析Storeへの読み取り専用問い合わせ |
| `optimize` | findingsをClaude Codeの対話へ渡して調査・修正案を得る |

初回や読み取り表示前に解析Storeを最新化し、変更のない入力は読み飛ばす。`--frozen`は自動更新を抑える指定と説明される。scope、出力形式、コマンド別対応範囲の詳細は原本に残した。

## 計測と変更判断の責務

常時Contextは、自分の指示・ルール由来と、システム・組み込みツール・MCP等の残りを分ける。自分のファイルを短くするだけでは削れない負担もある。

Viewには推奨アクションがあるが、計測値をそのまま削除命令にする設計ではない。`optimize`は裏付けとfindingsを一時ファイル経由でClaudeへ渡し、その時点のモデルが原因・修正を考える、という役割分担である。

記事のcd反復やawk / sedルールの例は、この対話から得た提案として読む。cclens自身が特定の直し方を機械的に保証した例ではない。

## 解析基盤の分離

```text
JSONL・設定 → adapter → core → SQLite Store → report
```

adapterが生形式、coreがイベント・コスト・join等の純粋な計算、storeが保存、reportが表示を担当する。生形式の変更をadapterへ閉じ込め、coreは時計・I/O・SQLを外して小さなfixtureで検証する設計が記事に紹介される。

Storeは増分解析で作る再構築可能なキャッシュであり、生トランスクリプトや設定をそのままコピーした正本ではない。未知の入力フィールド等を許容する方針も、任意の形式変更へ永続的に対応できる保証とは分ける。

## ローカル性と未確認事項

記事ではcclens本体はローカル解析でデータを送信しないと説明される。一方、`optimize`で渡したfindingsは通常のClaudeセッションとしてモデルへ送られる可能性がある、というのが原資料の推測である。解析本体と外部モデルを使う対話を区別する。

記事時点ではmacOS / Linux対応、Windows非対応。読者のWindows 11動作報告はブランチ適用の報告であり、現在の正式対応を確定する材料にはしない。

`stuck`・`waste`の閾値、失敗分類、記事後の仕様変更、解析費用とディスク使用量、`optimize`のデータ取り扱いは未確認である。

## 関連・参考資料

- [[TokenEconomizerによるセッション学習と費用削減]]：計測・棚卸しと、自動介入・設定書き込みの違い。
- [[Anvayaのローカル記憶とContext圧縮]]
- [[DeepSeek Harnessのプラグイン構成とKVキャッシュ]]
- [[AI開発の用語とハーネスの階層]]
- 原本：[[Sources/cclens/cclensのセッション分析と開発支援の元資料]]。
- 元ファイル：`cclens-Knowledge-20261102.md`。
- 資料の調査日・取り込み日：2026-11-02。
- 提供資料の主な参照先：[作者の紹介記事](https://zenn.dev/lambdalisue/articles/introduce-cclens)、[Repository](https://github.com/lambdalisue/cclens)。
