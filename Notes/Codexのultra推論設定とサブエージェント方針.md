---
type: Reference
status: Researching
topics:
  - Codex
  - reasoning effort
  - サブエージェント
  - オーケストレーション
  - API互換性
follow_up: true
follow_up_type: research
created: "2026-10-26"
updated: "2026-10-26"
---

# Codexのultra推論設定とサブエージェント方針

提供資料が調査したCodexでは、`ultra`はAPIへそのまま送る推論値ではなく、**モデルに応じた送信値への変換と、サブエージェントへの委任方針を組み合わせた設定**として扱われる。

このノートは2026-10-26作成の提供資料を整理したもの。調査対象は`openai/codex`のコミット`970111f6cb62cc02fe36a82ea7d71b37a2889c97`（資料記載日：2026-10-23）であり、今回の取り込みでコードや現行APIを再検証していない。同梱カタログ、実行時カタログ、実際に渡される指示は区別する。

## 三つの軸を分ける

| 軸 | 資料での決まり方 | ultraとの関係 |
|---|---|---|
| 送る`reasoning.effort` | モデル情報を使って変換 | `ultra`以外の対応値へ置き換える |
| 委任の方針 | `MultiAgentMode`と上書き文言 | v2では通常Proactiveへ切り替わる |
| 委任ツールの公開 | `multi_agent_version`と設定 | effortそのものは公開条件に入らない |

ツールが見えていること、自発的な委任が指示されていること、実際に子Agentが起動したことを同じものとして扱わない。この資料内の方針説明が、現在の会話や作業に適用される指示を変更するわけでもない。

## 送信値の変換

資料によると`ModelInfo::resolve_reasoning_effort`が変換を担い、`build_reasoning`等のリクエスト組み立て経路から使われる。

```text
ultra
  1. multi_agent_reasoning_effort
     （ultra以外で、そのモデルの対応値に含まれる場合）
  2. max（対応している場合）
  3. supported_reasoning_levelsを後ろから見た、ultra以外の最初の値
  4. medium（上記に候補がない場合）

persistent → "disabled"
その他     → そのまま
```

後ろから選ぶ処理を、任意の値名を意味的に並べ替えて最大値を計算する処理と読み替えない。`Custom`として受け取る値も、サーバーが受理する保証とは別である。`persistent`が実際の動作をどう変えるかは、提供資料の未調査事項である。

| モデルの対応値 | カタログの指定 | ultraの送信値（資料中のテスト） |
|---|---|---|
| high, max, ultra | high | high |
| high, max, ultra | なし | max |
| high, xhigh, ultra | なし | xhigh |
| high, xhigh, ultra | ultra | xhigh |
| high, xhigh, ultra | 未対応のlow | xhigh |

## 同梱カタログの記録

調査コミットの同梱`models.json`では、資料に次の対応が記載されている。

| モデル | ultra選択時の送信値 |
|---|---|
| gpt-6-astra、gpt-6.1-sol | xhigh |
| gpt-6-sol、gpt-5.6-sol、gpt-5.6-terra | max |
| gpt-6-luna、gpt-5.6-luna、gpt-5.5 | 当該同梱カタログではultra選択肢なし |

実行時に`/models`から得るカタログやキャッシュと同じ値かは未確認であり、現在のモデル提供状況の一覧として一般化しない。「ultraなら常にmax」と決め打ちしないことが要点になる。

## 委任方針の切り替えと優先順位

資料が説明する`effective_multi_agent_mode`は、`multi_agent_version`がv2の場合、通常はultraで`Proactive`、それ以外で`ExplicitRequestOnly`を選ぶ。

- `ExplicitRequestOnly`：利用者、AGENTS.md、Skill等が明示的に求めた場合だけ委任する旨を伝える。
- `Proactive`：時間・品質上の利点がある場合に自発的な委任を行う旨を伝える。
- `Custom`：指定された文言を使う。

設定の`multi_agent_mode_hint_text`やカタログに上書き文言がある場合は、effortからの通常選択よりそちらが優先される。空の文言も上書きとして扱われ、その場合は方針メッセージを入れない、と資料は説明している。

このため、ultraの名前だけで最終的な委任方針を断定しない。利用者の指示や実行時に渡された方針も別途確認する。Proactiveは実行を誘導する方針であり、必ず子Agentを起動することや性能向上を保証する説明ではない。

v2の子起動では、送信値へ変換したeffortを起動記録に残す一方、子の設定値は変えないとの説明がある。子が親から設定を継承する条件自体は未調査である。

## maxとの違いと画面上の扱い

| 比較点 | max | ultra（上書きのないv2の通常経路） |
|---|---|---|
| 送信値 | max | モデル別指定または対応するフォールバック値 |
| 委任方針 | ExplicitRequestOnly | Proactive |
| ツール公開 | 別設定による | 別設定による |

maxでも明示的な委任依頼があれば、利用可能な同じツールで委任できる。ultraを「maxより深いAPI推論値」と捉えるより、送信値と委任方針をまとめたCodex側のプリセットと捉える、というのが提供資料の検討結果である。

調査対象のTUIはmaxとultraを`More reasoning…`にまとめ、使用量の消費に関する説明を出す。また、ultraへの切り替え時に`max_concurrent_threads_per_session`が8以上なら警告する処理がある。これは資料時点のUI動作であり、普遍的な上限や推奨値として採用しない。

## 外部ハーネスのHTTP 400事例

提供資料には、外部ハーネスでmaxは完了し、ultraだけHTTP 400になった事例がある。変換せず`"effort": "ultra"`を送ったことが原因ではないかと推測されているが、リクエスト本文とエラー本文は未確認であり、原因は確定していない。

`supported_reasoning_levels`が表すCodex側の選択肢と、接続するAPIへそのまま渡せる値は分けて扱う。

資料の検討では、外部ハーネスは次の境界を分けて設計する。

- APIへ直接送る値だけを選択肢にするか、Codex固有設定も扱うか。
- ultraを扱う場合、モデル別情報に沿って送信前の変換を行うか、Codex本体へ解決を任せるか。
- effortの変換と、委任機構・委任方針を分離する。
- 自前のオーケストレーターでは、作業者ごとの推論強度と、自発的に作業者を増やす設定を別に持つ。

変換だけを実装しても、委任機構まで自動的に追加されるわけではない。逆に、値を制限しても他の原因によるHTTP 400までなくなる保証はない。

## 未確認事項

- HTTP 400時の実リクエスト・レスポンス本文。
- `/models`由来の実行時カタログと同梱情報の差。
- カタログによる委任方針文言の上書き有無。
- 子Agentのeffort設定が親から継承される条件。
- `persistent`と送信値`disabled`が変える具体的な動作。
- 調査コミット以降の実装変更や、他製品の同名設定。

## 関連

- [[AI開発の用語とハーネスの階層]]
- [[サブエージェントとオーケストレーション]]
- [[複数AIエージェントのオーケストレーション]]
- [[AI-DEの指示生成と実行時統制]]
- [[LLMの「賢さ」と品質グラフの読み方]]

## 参考資料

- 原本：[[Sources/Codex Reasoning/CodexのUltra推論とモデル別設定の元資料]]。関数・テスト・TUI・モデル管理に関する参照ファイル一覧を全文保存。
- 元ファイル名：`Codex-Ultra-Reasoning-Knowledge-20261026.md`。
- 資料の調査日・取り込み日：2026-10-26。
- 提供資料の調査対象：[openai/codexのコミット970111f](https://github.com/openai/codex/tree/970111f6cb62cc02fe36a82ea7d71b37a2889c97)。

