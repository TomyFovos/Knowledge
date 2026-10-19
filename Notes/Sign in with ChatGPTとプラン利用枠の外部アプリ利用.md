---
type: Reference
status: Researching
topics:
  - ChatGPT
  - Sign in with ChatGPT
  - OAuth
  - 外部アプリ連携
follow_up: true
follow_up_type: research
created: "2026-10-14"
updated: "2026-10-14"
---

# Sign in with ChatGPTとプラン利用枠の外部アプリ利用

> このノートは2026-10-14更新の提供資料を整理した記録である。以下の提供状況・技術条件は資料の調査時点の記載であり、今回の取り込みでは外部サイトを再検証していない。導入時には最新の仕様・規約を確認する。

## 概要

**Sign in with ChatGPT（SIWC）による認証**と、**ChatGPT plan usageによる推論利用枠の使用**は別の権限である。対応アプリでは追加認可により、利用者のAPIキー入力なしでChatGPTプランの利用枠を推論に使える。

ログインができるだけでは利用枠を使えず、利用枠を接続しても対象外のモデル・機能・実行基盤の費用は残る。外部アプリへの接続で利用枠そのものが増えるわけでもない。

## 認証・推論・課金を分けて考える

| 区分 | 役割 | 注意点 |
|---|---|---|
| Identity | ChatGPTアカウントで外部アプリへサインインする | 推論利用の認可とは別 |
| plan usage | 対応AI推論を本人のChatGPT利用枠へ計上する | 対応アプリ、プラン、モデル、上限に依存 |
| 外部アプリ料金 | サービス機能、実行基盤、対象外AI処理など | ChatGPT枠の接続後も発生しうる |

接続だけでChatGPTの会話履歴やメモリが外部アプリへ公開される権限は付かない。一方、外部アプリに入力した内容には、そのアプリの規約・プライバシー方針が適用される。

BYOKは利用者のAPIキーを使って通常API契約へ計上する方式、BYOSは利用者のサブスクを接続する方式を指す。BYOSは提供資料で用いた説明用略称であり、資料が挙げる正式名称はChatGPT plan usageである。

## 導入経路は商用とOSSローカルで異なる

| 経路 | 資料時点の整理 | 未確認・確認が必要なこと |
|---|---|---|
| 商用Web SaaS | 選定パートナー向け限定提供、申請窓口あり | 一般開発者のセルフサービス導入、個別契約・課金条件 |
| OSSローカル | 動的クライアント登録と公開Responses APIのフローあり | 規約、DevKit非商用ライセンス、認可・保存・上限処理 |
| iOS | 公開OSS callbackはHTTP loopback、公式DevKitはNode.js / React・macOS中心 | Swift SDK、iOS正式対応、callback種別、商用承認・配布条件 |

商用実例があることを、一般開発者が同じ条件で導入できる根拠にしない。OAuth + PKCEを実装できることだけで、iOSや商用サービスへの導入可否は判断できない。

## サービス別の費用境界

| サービス | 資料に記載された対応条件・注意点 |
|---|---|
| Notion Agent | Notion Business / Enterpriseのメンバー、ChatGPT Plus / Pro。ゲスト・Custom Agentsは対象外。特定GPTモデルはChatGPT枠、Autoや他モデルはNotion側 |
| Warp Agent | アプリ内の対応OpenAIモデルで利用。AutoはWarp枠、保存済みAPIキーが優先。クラウドAgentは対象外、プラットフォーム料金は残りうる |
| Vercel v0 | 開発中の対応生成で利用。画像生成・一部サブエージェント等はv0クレジット。公開後の生成アプリのAPI費用は対象外 |
| Amp Code | `amp add-chatgpt-sub`で接続。モデル・ロールによってAmpクレジット消費が残る |

元資料によると、Notionは2026-10-13の3.8で発表された。Warpやv0は10月14日に確認した事例であり、すべてが10月5日以降の新規公開という意味ではない。

## 利用枠と上限

- 利用者向けHelpのGo / Plus / Pro表記と、開発者資料・各アプリのPlus / Pro条件には差がある。Goの全アプリ対応は未確認。
- 既存のChatGPT Work / Codex系利用枠を共有し、外部アプリ専用の枠が追加されるわけではない。
- `Settings → Usage`でアプリ別消費や週次割合上限を管理する。アプリ上限は利用枠の予約ではない。
- OSS資料ではPlusの5時間制限は参加アプリ間で共有し、Proには同じ5時間制限がないとされる。ただし無制限という意味ではない。
- 上限後のChatGPTクレジットや別経路への切り替えは明示的な選択を前提とする。

## OSS公開経路の技術概要

```text
ローカルOSSアプリ → ブラウザーでログイン・追加認可
→ PKCEでトークン交換 → トークンをローカルで保護
→ OAuth Bearer tokenでPOST /v1/responses
→ 対応推論を本人のChatGPT枠に計上
```

提供資料に記載された主要条件：

- OAuth 2.0 Authorization Code + PKCE、OpenID Connect。
- Identity：`openid profile email`。
- plan usage：`offline_access resource.invoke chatgpt.tokens.use.direct`。
- 初回動的登録：`client_id=dynamic_agent_client`。
- callback：`http://127.0.0.1:<port>/auth/callback`。
- 公開API：`https://api.openai.com/v1/responses`。
- HTTPは`store: false`、`stream: true`。成功判定は`response.completed`受信まで待つ。
- HTTPの`previous_response_id`による継続は使えず、履歴を`input`に送る。
- 画像生成、File Search、Code Interpreter、ネイティブComputer Use、ホスト型MCP / connectors、`tool_search`などは当該Preview経路で非対応。
- 音声・動画入力、Files upload API、一部フィールド（`background`、`conversation`、`temperature`、`max_output_tokens`など）にも制限がある。

これらはOSS公開経路の仕様記録であり、商用パートナーの非公開実装条件まで同じとは確認されていない。

## セキュリティと規約の確認点

ID tokenの署名・issuer・audience・nonce、OAuthの`state`とPKCEを検証する。アクセストークン・更新トークンは保護ストレージへ保存し、ログ、URL、ブラウザーストレージ、ソースコードへ漏らさない。

資料によると、一般SIWC規約には利用者管理下でのトークン保存・リクエスト実行、プラン利用のためにアプリへの支払いを要求しない条件、他人の枠流用・制限回避・枠やトークンの共有再販を禁止する条件がある。
一方、商用実例には有料プランや別途サービス料金がある。一般規約と個別商用提携条件の適用関係は公開資料だけでは未確認とされている。

公式DevKitのOpenAI作成コードは非商用ライセンスと記載されており、認証仕様を使えることとDevKitを商用再利用できることも分けて確認する。

## 未解決事項

- 商用クライアントIDの一般開放と承認条件。
- 一般規約の課金条項と商用提携契約の関係。
- Goの対応範囲と、各アプリの対象プラン。
- Swift SDK、iOS正式対応、Universal Link / custom scheme。
- Previewの会話状態・ツール・非同期・画像生成制限の緩和。
- 企業ユーザー管理、監査、請求、データ処理契約、管理者承認。
- 複数アプリとChatGPT本体で共有した場合の実消費率・上限。

## 関連ナレッジ

- [[ChatGPT有料版でできること]]
- [[ChatGPT調査にXのリアルタイム情報を組み込む]]

## 参考資料

- 提供資料の読取記録（技術条件、実例、参考URL20件を収録）：[[Sources/ChatGPT/Sign in with ChatGPTとプラン利用枠の外部アプリ利用の読取記録]]。
- 元ファイル名：`Sign-in-with-ChatGPT-Plan-Usage-Knowledge-20261014.md`
- 初回整理：2026-10-05、資料更新日・取り込み日：2026-10-14。
- 元ファイルは読み取り後にDownloadsから見つからなくなったため、完全コピーは未保存。読取記録は取得済み本文を整理して復元したものである。
