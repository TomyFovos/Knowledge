# Sign in with ChatGPT と ChatGPT plan usage 技術ナレッジの読取記録

元ファイル：`Sign-in-with-ChatGPT-Plan-Usage-Knowledge-20261014.md`。
資料更新日：2026-10-14、初回整理：2026-10-05。
取り込み時に元ファイルを読み取った後、Downloadsから見つからなくなったため、取得済みの本文から主要内容・技術条件・参照先を保存した記録である。元ファイルの完全コピーではない。本文の確認区分は提供資料の調査結果を示し、今回の取り込みで独立に再検証したものではない。

## 概要と調査目的

資料は、SNSの「ChatGPTのサブスク枠を外部アプリに組み込める」「無制限にAIを使える」という主張を、単なるOAuthログインとの違い、iOS・Webへの導入条件、商用実例から検討している。

Sign in with ChatGPT（SIWC）は外部アプリへのChatGPTアカウントによるログインである。対応アプリでは、追加認可によりChatGPTプランの利用枠をAI推論に使える。資料ではこの機能をChatGPT plan usageと呼ぶ。利用できるアプリ・モデル・機能・利用枠には制限がある。

## 結論

1. Identityとplan usageは別の権限。ログインだけでは推論をプランへ計上できない。 [S01] [S02]
2. 対応するリクエストは利用者本人のChatGPT利用枠を消費し、利用者のAPIキー入力は不要。ただし上限・アプリ制限がある。 [S02]
3. Notion Agent、Warp Agent、v0、Amp Codeには公式に説明された商用実例がある。 [S05] [S06] [S07] [S08]
4. 商用SIWCは選定パートナー向けの限定提供であり、一般Webサービスへのセルフサービス導入は確認されていない。申請ルートがある。 [S01] [S16]
5. OSSローカルアプリには動的クライアント登録、トークン取得、Responses API、DevKitの公開フローがある。 [S09] [S10] [S11]
6. 一般SIWC規約の課金・保存・実行条件と、商用提携サービスの料金条件との適用関係には未解決事項がある。 [S04] [S05] [S15]

## 時系列

| 日付 | 提供資料で記録された出来事 |
|---|---|
| 2026-09-23 | Warp変更履歴にChatGPTプラン連携掲載 [S17] |
| 2026-09-29 | OpenAI DevDay 2026でSIWC / plan usage発表 [S12] |
| 2026-10-01 | Vercelがv0の連携を解説 [S07] |
| 2026-10-05 | 会話で初回整理 |
| 2026-10-11 | Warp接続ガイド更新 [S06] |
| 2026-10-13 | Notion 3.8で連携発表 [S13] |
| 2026-10-14 | 公式文書・実例・規約を再整理 |

10月14日に確認した事例がすべて10月5日以降に公開されたわけではない。Notionの発表は新しい進展、Warpやv0は既存実装の追加確認という側面がある。

## Identityとplan usage

| 項目 | Identity | plan usage |
|---|---|---|
| 主目的 | 外部アプリへのサインイン | 対応推論へのプラン利用枠使用 |
| 許可 | アカウント識別情報など | Responses APIに必要な追加権限 |
| APIキー | 不要 | 不要 |
| ChatGPT履歴・メモリ参照 | 付与されない | 付与されない |
| 条件 | 対応アプリ | アプリ、プラン、モデル、上限に依存 |
| 開発者の導入 | 商用は限定パートナー | 商用は限定パートナー、OSSローカルには公開経路 |

認証方式はOAuth 2.0 Authorization Code + PKCEとOpenID Connect。Identityスコープは`openid profile email`、公開OSS経路のplan usageスコープは`offline_access resource.invoke chatgpt.tokens.use.direct`。 [S01] [S09]

## OSSローカルアプリの技術経路

```text
利用者PCのOSSアプリ → システムブラウザーでOpenAIにログイン
→ Identityとplan usageを別途認可 → code / issued client_id
→ PKCEトークン交換・ID token検証 → ローカルでトークン保護
→ Bearer tokenでPOST https://api.openai.com/v1/responses
→ 対応推論を利用者のChatGPT枠へ計上
```

初回は`client_id=dynamic_agent_client`で動的登録する。クライアント秘密鍵や開発者APIキーを要求しないが、発行`client_id`、ユーザー認証情報、`ext_agent_host_id`、トークン保護・更新は実装者の責任。商用パートナーが同じ保存方式やネットワーク構成を使うとは確認されていない。 [S09]

公開Responses APIを使用し、非公開`backend-api`の独自呼び出しとは区別する。模式例は次のとおり。 [S10]

```http
POST /v1/responses HTTP/1.1
Host: api.openai.com
Authorization: Bearer <ACCESS_TOKEN>
Content-Type: application/json

{
  "model": "<ACCOUNT_SUPPORTED_MODEL>",
  "input": [{"role": "user", "content": "Hello"}],
  "store": false,
  "stream": true
}
```

モデルはアカウントの対応モデル一覧から選び、ストリームの`response.completed`受信まで成功と見なさない。

## サービス別実例

### Notion Agent

Notion 3.8で2026-10-13に公開。条件はNotion Business / Enterpriseのメンバー、ChatGPT Plus / Pro、Notion Agent。ゲストとCustom Agentsは対象外。 [S05] [S13]

`Settings → Notion AI → Usage → Connected subscriptions`またはモデル選択から接続する。特定GPTモデルはChatGPT枠、`Auto`やGPT以外はNotionクレジット。ChatGPT上限ではNotionクレジットへの切り替えを尋ね、枠回復時にはChatGPTへ自動復帰すると説明されている。 [S05]

会話はChatGPTの履歴・メモリに表示・保存されず、NotionのAIサブプロセッサ契約と保持方針が適用される。提供資料によるとNotion AIの保持はEnterpriseでは保持なし、それ以外は30日。商用実例があることと一般開発者が同じ契約条件を使えることは別である。 [S05]

### Warp Agent

Warpアプリ内の対応OpenAIモデルではChatGPT枠を使える。`Auto`はWarp枠、保存済みOpenAI APIキーはChatGPT接続より優先。クラウドAgentの実行原資には使えず、Business / EnterpriseのローカルAgentにはプラットフォーム料金が発生しうる。上限時などのWarpクレジット切り替えは利用者が選ぶ。 [S06]

### Vercel v0

クレジットメニューの`Use ChatGPT plan`から接続。画像生成、delegated subagents、一部支援処理にはv0クレジットが必要になりうる。アプリ開発中の利用枠共有であり、生成アプリの公開後のOpenAI API料金を肩代わりするものではない。 [S07]

### Amp Code

`amp add-chatgpt-sub`で接続可能。モデル・ロールによってAmpクレジット使用も残る。`ChatGPT Only`プリセットなどが提供される。 [S08]

### DevKitとディレクトリ

公式`sign-in-with-chatgpt-devkit`は`@siwc/local`、`@siwc/react`、macOSサンプル「Paste Perfect」を含む。OpenAI作成コードにはSign-in with ChatGPT DevKit Noncommercial License v1.0が適用され、商用再利用には確認が必要。従来の独自ChatGPT / Codex認証利用と正式SIWC仕様公開を分ける。 [S11]

2026-10-14時点の掲載記録： [S03]

| 区分 | サービス |
|---|---|
| plan usage | Amp Code、Conductor、Dactyl、Devin、Hermes Agent、Hyperagent、Kilo Code、Notion、Vercel、Vorflux、Warp |
| 対応予定 | Lovable（coming soon） |
| ログインのみ | Airtable、Canva、GitLab、HubSpot、Supabase |
| OSS | OpenClaw、OpenCode、Pi、T3 |

掲載だけでは対象プラン・モデル・機能の全範囲は確定しない。

## プラン・料金・利用枠

利用者向けHelpはGo / Plus / Pro、開発者Quickstartとディレクトリは主としてPlus / Pro、NotionもPlus / Proを記載。Goの全サービス対応は断定できない。Identityは広くChatGPTアカウント利用者向けだが、Enterpriseは管理者設定に依存する場合がある。 [S01] [S02] [S03] [S05] [S14]

- 外部アプリ使用は既存ChatGPT Work / Codex系利用枠へ計上され、枠が増えるわけではない。 [S02]
- `Settings → Usage`でアプリごとの使用量と週次割合上限を管理する。上限は別枠付与や予約ではない。 [S02]
- OSS文書ではPlusの5時間制限は参加アプリ間共有、Proは同じ5時間制限なし。ただしすべての制約がなくなる意味ではない。 [S18]
- 上限後のChatGPTクレジットは明示許可が必要で、自動別課金ではない。 [S02]
- 外部サービスの料金、実行基盤、対象外機能の費用は別途発生しうる。 [S02] [S05] [S06] [S07]

## 商用・規約の未解決事項

商用は選定パートナー限定で問い合わせフォームがあり、独自Web SaaSが認証画面だけで利用枠連携できるとは言えない。 [S01] [S16]

一般SIWC規約にはトークン永続保存を利用者管理下のローカル環境に限ること、リクエストを利用者管理下のランタイムから送ること、プラン利用のためにアプリへの支払い・有料化を要求しないことなどが記載されている。対してHelpは商用アプリの別途料金を説明し、NotionはBusiness / Enterpriseに限定する。公開資料間の適用関係、個別提携契約の扱いは未確認であり、有料SaaSの導入判断にはOpenAIとの個別確認が必要と資料は整理している。 [S02] [S05] [S15]

## iOS

OSS callbackは`http://127.0.0.1:<port>/auth/callback`でホスト・スキーム・パス固定。DevKitはNode.js / React、macOS中心で、提供資料の調査では公式Swift / iOS SDKや実装例を確認していない。 [S09] [S11]

iOSでローカルcallbackを扱う実装の検討余地と、正式サポートは別。App Store配布や商用利用には提供条件、ライセンス、審査を別途確認する。一般開発者の商用iOSへのセルフサービス導入を裏付ける公式根拠は確認できない、という結論。

## OSS PreviewのAPI制限

以下は公開OSS経路の条件であり、商用パートナーの非公開条件に一律適用できるとは確認されていない。 [S19]

- HTTPでは`store: false`、`stream: true`を要求。
- HTTPの`previous_response_id`で永続継続できず、履歴を`input`へ送る。
- 画像生成、File Search、Code Interpreter、ネイティブComputer Use、ホスト型MCP / connectors、Responses `tool_search`は非対応。
- 対応モデルのテキスト・画像・ファイル入力は可能だが、音声・動画入力、Files upload APIは非対応。
- `background`、`conversation`、`temperature`、`max_output_tokens`など一部フィールドは使えない。
- 上限・権限不足・非対応機能をUIに通知し、勝手に別の課金経路へ移行しない。 [S20]

## セキュリティ・プライバシー

接続だけでChatGPT会話履歴・メモリを公開する権限は付かない。ただし外部アプリへ入力した内容は外部アプリの規約・プライバシー方針に従い、SIWCが外部サービスの安全性を保証するわけではない。 [S01] [S02]

OSSではID tokenの署名・issuer・audience・nonce、OAuth `state`、PKCEを検証する。アクセストークン・更新トークンは保護ストレージへ保存し、ログ、URL、ブラウザーストレージ、ソースコードへ漏らさない。規約は他人の枠流用、アカウント循環による制限回避、枠・トークン再販や共有を禁止すると資料に記載されている。 [S09] [S15] [S18]

## BYOKとBYOS・導入の整理

- BYOK：利用者のAPIキーで通常API契約へ計上する。
- BYOS：利用者のChatGPT契約を接続し、対応推論をサブスク枠へ計上する。BYOSは資料内の説明用略称で、正式名称はChatGPT plan usage。
- OSSローカル：APIキー準備の手間を省けるが、利用者認可、トークン保存、モデル選択、上限表示、エラー処理、規約・DevKitライセンスを確認する。
- 商用Web SaaS：サービス機能と推論枠を分離する実例はあるが、一般導入には承認・契約・対象プラン・fallback・表示条件の確認が必要。
- iOS：OAuth + PKCEの実装可能性だけでは導入可否を判断できない。クライアント種別、callback、SDK、保存条件、商用承認を追跡する。

## 今後確認したいこと

1. 商用クライアントIDのセルフサービス一般開放。
2. 一般規約の課金条項と商用提携条件の関係。
3. Go対応範囲と各アプリのPlus / Pro条件の差。
4. Swift SDK、Universal Link / custom scheme、iOS正式対応。
5. Previewの会話状態・ツール・非同期・画像生成制限の緩和。
6. 企業ユーザー管理、監査、請求、データ処理契約、管理者承認。
7. ChatGPT本体・Notion・v0等の共有枠の消費率と実効上限。

## 提供資料の参考資料一覧

以下は提供資料が2026-10-14に確認したと記録している参照先である。

- [S01] https://developers.openai.com/siwc/quickstart
- [S02] https://help.openai.com/en/articles/20001542-using-your-chatgpt-plan-in-other-apps-and-sites
- [S03] https://learn.chatgpt.com/docs/sign-in-with-chatgpt
- [S04] https://openai.com/policies/sign-in-with-chatgpt-terms/
- [S05] https://www.notion.com/en-gb/help/use-your-chatgpt-plan-with-notion-agent
- [S06] https://docs.warp.dev/agents/inference/chatgpt-subscription/
- [S07] https://vercel.com/i/openai-devday-2026
- [S08] https://ampcode.com/docs/the-dial
- [S09] https://developers.openai.com/siwc/token-sharing-open-source/sign-in
- [S10] https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference
- [S11] https://github.com/openai/sign-in-with-chatgpt-devkit
- [S12] https://openai.com/index/devday-2026-recap/
- [S13] https://www.notion.com/releases/2026-10-13
- [S14] https://help.openai.com/en/articles/20001410-sign-in-with-chatgpt
- [S15] https://openai.com/ja-JP/policies/sign-in-with-chatgpt-terms/
- [S16] https://openai.com/form/sign-in-with-chatgpt-interest/
- [S17] https://docs.warp.dev/changelog/2026/
- [S18] https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions
- [S19] https://developers.openai.com/siwc/token-sharing-open-source/preview-limitations
- [S20] https://developers.openai.com/siwc/token-sharing-open-source/errors-and-recovery

## 元資料の更新履歴

- 2026-10-05：Identityとplan usage、OSS、商用Web、iOSの疑問を初回整理。
- 2026-10-14：Notion 3.8、Warp、v0、Amp、パートナー一覧、Go表記差、利用枠制御、規約と料金、iOS課題を統合して全面更新。
