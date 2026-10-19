---
type: Pattern
status: Researching
topics: [AI-DE, ハーネス, 実行統制, 指示管理]
created: "2026-10-19"
updated: "2026-10-19"
follow_up: true
follow_up_type: research
---

# AI-DEの指示生成と実行時統制

AI-DEの設計資料では、エージェントへの指示を生成する仕組みと、実行時に権限・正式状態を強制する仕組みを分離する。指示は行動を誘導し、Runtimeは許可された作用だけを成立させ、Evidenceで結果を確認する。

このノートの根拠は、2026-09-22時点の会話を統合した引継ぎ資料に基づく説明文書である。現行リポジトリの監査結果や、外部ハーネスの現在仕様を示すものではない。

## 指示の正本と読ませる表示面を分ける

```text
docs/ai-instructions/*（指示内容の正本）
        ＋ profiles.yaml（適用条件の正本）
        ↓ Registry（選択）
        ↓ Renderer（生成）
AGENTS.md / Harness別生成物 / generated-instructions-index.json
```

資料中の`profiles.yaml`の位置は`config/ai-instructions/profiles.yaml`、Inventoryは`.github/ai-de/generated-instructions-index.json`。Registry / Rendererの具体的な実装ファイル名は確認範囲に含まれない。

共通規範をハーネスごとに手作業で複製せず、生成物を第二の正本にしない。生成物の直接編集や正本との差はdriftとして検出する設計である。

## 共通入口と固有機能

資料ではSelf-developmentとConsumer双方の共通入口を`AGENTS.md`に統一し、生成された`CLAUDE.md`を共通入口として退役させる決定が記録されている。

Claude固有機能は`.claude/rules/*`、`.claude/skills/*`、`.claude/agents/*`、`.claude/settings.json`へ置く。由来不明のユーザー所有`CLAUDE.md`を名前だけで自動削除する設計ではない。

これは当該プロジェクトの設計決定であり、このナレッジリポジトリで入口ファイルを変更・削除する指示ではない。

## Profileは用途を分ける

自己開発と、顧客Projectを開発するConsumerでは、必要な工程指示が異なる。Consumer向けの要件質問やUIレビュー等を自己開発へ常時適用しないよう、共通指示を消すのではなく適用範囲を分ける。

自己開発の指示を軽くしても、RuntimeのSecurity、Gate、Evidenceは残る。Profileを権限上の最低条件の解除に使わない。

## 指示に書くことと強制すること

| 対象 | 指示層 | Runtime側 |
|---|---|---|
| 作業方針 | 説明・誘導 | 必要に応じて機械検証 |
| 使用ツール・権限 | 許可範囲を伝える | Capability・Guardで制限 |
| 正式な仕事 | 作業内容を伝える | Plan / Task Graphが所有 |
| 子Agentの仕事追加 | 自由な増殖を禁止する | 正式Task化は管理側へ戻す |
| 外部作用 | 注意事項を伝える | Operationとして追跡 |
| 完了 | Agentが報告する | 対象revision・Artifact・Evidenceを確認 |
| 障害後の再開 | 方針を伝える | Attempt / Recovery / Reconciliationで管理 |

仕事の正本をAgent Treeへ置かず、下位Agentや子Agentが委譲権限を広げない。Workerを増やしても判断権限が増えるわけではない。

## 鮮度確認と信頼境界のdigestは用途が違う

指示の鮮度は、期待するcanonical contentと実ファイルの直接比較を使う方向で整理されている。Inventoryは適用先の追跡用であり、本文の真正性を決める第二の台帳ではない。

一方、Execution Packet、Evidence、署名、provenance、revision bindingなどで必要なdigestを廃止する意味ではない。

## 責務と未確認事項

資料ではAI-DEが長寿命のExecution Stateと統制、Agent HarnessがAgent loop・Session・Tools・内部sub-agent、ArthurがGoal・Requirement・Acceptance Criteria等の意味上の権限、Japan-HarnessがProvider・Profile・Binding等のCompositionを担うと整理されている。

Registry / Rendererの実装、生成物の現行一覧、Claude側での`AGENTS.md`読込挙動は、最新revisionとRuntimeで別途確認する。資料が参照する「日本ハーネス_統合引継ぎ資料.md」本体は今回のZIPに含まれない。

## 関連・参考資料

- [[AI-DEにおけるハーネスの位置づけと設計境界]]
- [[AI-DEのState Storeと障害回復]]
- [[AI実行ガバナンスと人間の監督]]
- 全文：[[Sources/Mixed Memos 20261019/Markdown/AI-DEのエージェントハーネス構成と設計思想（提供資料）]]

