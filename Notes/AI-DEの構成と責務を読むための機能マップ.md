---
type: Reference
status: Researching
topics: [AI-DE, 日本ハーネス, アーキテクチャ]
created: "2026-10-19"
updated: "2026-10-19"
---

# AI-DEの構成と責務を読むための機能マップ

提供された`preview (1).html`は、日本ハーネスの全体構成、AI-DE内部、LLM通信、外部知識、検証、権限、全機能を7枚のSVGと対応説明で整理している。

図解の作成日・現行実装との一致は不明である。State Store資料や指示生成資料とは説明の時点・粒度が異なり、すべてを一つの確定アーキテクチャへ統合しない。

## 全体の責務

| 部品 | 図解が説明する役割 |
|---|---|
| 人間 | 目的・承認・例外・リスク判断 |
| Orca | 状態の表示と操作。正本状態を所有しない |
| AI-DE | 作業の構成、実行統制、Gate、状態・証拠の管理 |
| Security Proxy | LLM通信の外部送信境界・必要なマスキング |
| OpenCodex | Provider接続・ルーティング部品 |
| STK | 汎用的なテスト観点の候補 |
| Document Asset | 既存文書・形式への適応 |
| Task Tracker | 外部の仕事の起点。Runtime Stateの正本ではない |

![[Assets/Images/未整理メモ20261019/AI-DEの構成と全機能マップ（図解資料）の図01.svg]]

## 内部機能を読む順序

1. Protocol HostがClient入力を受け、Coreが正式な計画・状態遷移を扱う。
2. State StoreがCurrent State、History / Audit、Artifact / Evidence参照を保持する。
3. Execution PlanningがPacketと権限・入力・期待結果を固め、RuntimeがWorker / Toolを動かす。
4. 大きな成果物・証跡はLocal Object Store等へ置き、参照とdigestを記録する。
5. Platform Test、Fault Injection、Evidence Verificationで基盤自体の異常時動作も確認する。

## 図解に含まれる機能群

要件定義・QA、Governance・Gate・権限、計画とTask分解、Execution Runtime、状態・Artifact・Evidence、Model / Provider管理、開発知見とFeedback、Feature Trace Graph / Spider View、外部資産・課題管理連携、生成物検証、Recovery・長時間実行が列挙されている。

これは資料にある機能の位置づけであり、個々の完成度・提供可否を確認した一覧ではない。特に図解中の「AI-DEが持つAuthority」と、別の指示構成資料が説明するArthur等の意味上の権限は、資料の境界を保って読む。

## 原図への入口

全文Markdownに7枚すべてのSVGと説明を保存した。アイコンや別のプロジェクト紹介図は、[[未整理メモの整理結果（2026年10月19日）]]から画像一覧へ進める。

## 関連・参考資料

- [[AI-DEのState Storeと障害回復]]
- [[AI-DEの指示生成と実行時統制]]
- [[日本ハーネスの規範・事実モデルと設計凍結]]
- 全文：[[Sources/Mixed Memos 20261019/Markdown/AI-DEの構成と全機能マップ（図解資料）]]

