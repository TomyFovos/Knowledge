---
type: Reference
status: Researching
topics: [Microsoft Web IQ, Work IQ, MCP, Microsoft 365]
follow_up: true
follow_up_type: research
created: "2026-11-02"
updated: "2026-11-02"
---

# Microsoft Web IQとWork IQの役割と接続条件

Web IQは公開Webのグラウンディング、Work IQはMicrosoft 365の業務情報を扱う知能層として、2026-11-02の提供資料で区別されている。名前が似ていても、データ、認証、利用条件は異なる。

原資料は公式・第三者・転載情報・伝聞を区別しており、接続実機確認はしていない。今回の取り込みでも認証・MCP設定・外部再確認は行っていない。

## 二つの対象

| 項目 | Web IQ | Work IQ |
|---|---|---|
| 主な情報 | Web、ニュース、画像、動画 | メール、予定、Teams、ファイル等の業務情報 |
| 資料中の接続先 | `https://api.microsoft.ai/v3/mcp` | `https://workiq.svc.cloud.microsoft/mcp` |
| 条件の整理 | 限定提供・審査。認証ヘッダー詳細は未確認 | Entra委任認証、ライセンス、テナント有効化・管理者同意等 |
| 根拠の確度 | 公式案内を含む | endpoint・scope等は第三者資料由来も含む |

Work IQの一般提供時期・課金・ライセンスは資料間に不一致がある。転載で参照したAPI overviewの原本URLも未確認である。表の条件は完成した導入手順や現在の契約条件ではない。

## MCPで呼べる構成と、接続成功は別

Claude Code等のMCPクライアントから呼ぶ構成が紹介されるが、URLを登録するだけで認証・権限・アカウントの許可範囲まで解決するわけではない。

資料にあるWork IQ用のClaude Codeプラグインは第三者製で、公式パッケージを起動する手順と、プラグイン自体の提供元を区別する。Graphの生データ取得と、Work IQの解釈を含む層も別の役割として記録する。

Web IQのp95 164ms等はMicrosoft側の性能主張で、第三者検証や自環境の測定ではない。

## アプリ内とAPI経由の精度差は伝聞

「Office製品内で動くWork IQとMCP経由では精度・性能が違う」という話は開発者からの伝聞で、比較を裏付ける公開根拠は原資料で見つかっていない。

開いている文書・選択範囲等のContext、会話記憶、公開ツールの範囲、戻り値を解釈する呼び出し側モデルの違いは、差の原因候補として検討されているだけである。「MCPは単なるデータ取得だから劣る」「アプリ内だけ常時動く」と確定しない。

同じ質問・対象データ・認証範囲で比較し、発言者が何を比較したのか確認する案が残る。実施済みの評価ではない。

## 関連・参考資料

- [[Microsoft Copilotの現在地]]
- [[RustXNGによるメタ検索と組織内検索]]
- [[DevLoreによる開発経験の蓄積と再利用]]
- 原本：[[Sources/Knowledge Batch 20261102/Microsoft Web IQとWork IQの接続検討の元資料]]。
- 元ファイル：`WebIQ-WorkIQ-Knowledge-20261102.md`。
- 提供資料の主な参照先：[Web IQ](https://webiq.microsoft.ai/)、[Work IQ in Copilot Studio](https://learn.microsoft.com/en-us/microsoft-copilot-studio/use-work-iq)。
