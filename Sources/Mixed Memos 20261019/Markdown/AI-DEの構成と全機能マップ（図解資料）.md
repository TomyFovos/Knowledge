# AI-DEの構成と全機能マップ（図解資料）

HTMLの全本文をMarkdownへ変換した参照用コピー。画面用CSS・JavaScript・タブ切替UIは除き、タブ内本文、表、コード、Mermaid、SVG図は保持する。図や原表示は元HTMLも参照。

原本：[[Sources/Mixed Memos 20261019/Originals/メモ/preview (1).html]]

---

## 日本ハーネス アーキテクチャ — 日本語・アイコン版

主要ノードを「色 + アイコン + 短い日本語説明」で統一。各主要ノードはホバーすると補足説明を表示します。

見方 点線の下線が付いたラベル、または点線枠のノードにマウスを乗せると、日本語の詳しい説明が表示されます。目的 図だけで位置関係をつかみ、下の「この図の機能説明」で各機能を1対1で確認できる構成にしています。

![[Assets/Images/未整理メモ20261019/AI-DEの構成と全機能マップ（図解資料）の図01.svg]]

**人間・作業対象 **Control / UI **Knowledge / Asset **Security **Routing / Execution接続 **外部AI

**境界:** 日本ハーネスは巨大な単一Repositoryではなく、AI-DE・Orca・STK・Document Asset・Security Proxyなどを束ねる上位Architecture。OpenCodexは利用するRouting component、LLM ProviderやGitHub/Backlog等は外部接続先。

この図の機能説明

### 人間

目的を決める人です。AIが提示した計画を承認し、追加質問に答え、例外やリスク受容のような責任ある判断を引き受けます。

### Orca

人間がAI開発全体を見て、操作して、進捗を管理する画面です。正本状態は持たず、AI-DEが持つ状態を見せる立場です。

### AI-DE

開発ハーネス本体です。必要な作業を組み立て、権限を守ってAIを動かし、成果物が条件を満たしたかを確認します。

### セキュリティプロキシレイヤー

LLMに出ていく通信の境界です。必要に応じてマスキングを行い、外部送信を統制します。

### OpenCodex

AI-DEが特定のLLMへつながるための接続部品です。どのProviderを使うかの差を吸収します。

### LLM Provider群

実際に推論するAIです。ClaudeやOpenAI系などがここに入ります。Provider自体は権限やGateの正本を持ちません。

### STK

汎用的なテスト知識を提供します。『何をテストできるか』の候補を広く出しますが、『今回必ず何をやるか』は決めません。

### Document Asset

チームの既存ドキュメントや成果物形式を活用するための基盤です。AIを既存のやり方へ適応させる要の領域です。

### Task Tracker

Issueなどの外部仕事起点です。開発対象の入口ですが、AI-DEの実行状態そのものの正本ではありません。

![[Assets/Images/未整理メモ20261019/AI-DEの構成と全機能マップ（図解資料）の図02.svg]]

**SSOT原則:** Snapshotは保存された正本ではなくState Storeから再構築する。Protocol Eventは通知であり、Transactional Outboxから配信する。

この図の機能説明

### Protocol Host

ClientからのJSONメッセージを受け、AI-DE Coreへ渡す入口です。薄い橋渡し層として保ちます。

### アプリケーションサービス / Core

AI-DEの正式な判断を行う心臓部です。Plan、Task、Gate、Human Decision反映などをここで処理します。

### Current State

今このProjectがどこまで進んでいるかの最新状態です。PhaseやTaskの進捗を見るときに参照します。

### History / Audit

何がいつ起きたかの履歴です。監査、追跡、復旧判断の根拠になります。

### Artifact / Evidence Ref

成果物や証跡そのものではなく、それらへの参照情報です。重い実体は外部保存を前提にします。

### State Store基盤

SQLiteまたはPostgreSQLで実装されるRuntime Stateの保存先です。イベントや画面表示ではなく、ここが正本です。

### Execution Runtime

AIやツールを実際に動かし、AttemptとOperationを生成する実行基盤です。

### Execution Planning

どのTaskをどういう権限・入力・期待結果で実行するかを固める部分です。

### Worker / Tool 実行

CLI、テスト、ファイル変更、外部呼び出しなどを実際に行う部分です。Capabilityで制御されます。

### Execution Workspace

どのRepository / Worktree / Commitで実行したかを示す作業場所情報です。再現性と追跡性のために重要です。

### Local Object Store

大きな成果物や証跡をDigest参照で保持する保存先です。DBを肥大化させないための実体置き場です。

![[Assets/Images/未整理メモ20261019/AI-DEの構成と全機能マップ（図解資料）の図03.svg]]

この図の機能説明

### AI-DE Core

実行前に必要な権限や実行計画を固めます。実行中に好き勝手に条件を書き換えないための起点です。

### Security Proxy

外に出る前の最後の安全装置です。AIが読む文面そのものを保護したいときの境界です。

### OpenCodex / Provider Router

どのLLMへどう投げるかを扱います。AI-DEは『誰に依頼するか』を抽象化し、ここが実接続を担当します。

### Providers

実際の推論先です。ここで得た回答だけでは正式完了にならず、ResultやEvidenceまで揃う必要があります。

### Execution Packet

Taskを実行するときの実行指示書です。使ってよい権限、入力、期待する出力、制約などを含みます。

### Operation Log

AIが何をしようとし、何が起き、結果がどうだったかをIntent / Effect / Resultで残す記録です。

![[Assets/Images/未整理メモ20261019/AI-DEの構成と全機能マップ（図解資料）の図04.svg]]

**Document Asset詳細は別設計。** AI-DE CoreはStorage方式やDocument形式に直接依存せず、Document Asset Port経由で利用する。

この図の機能説明

### STK

テスト観点の知識源です。たとえば非同期処理や二重送信のような観点候補を出す役割です。

### Template

成果物の形式見本です。Excelの列構成や文書の節構成のように、『どういう形で出すか』を支えます。

### Exemplar

過去成果物の良い例です。AIが書きぶりや粒度を合わせる参考になりますが、それ自体がAuthorityではありません。

### Document Asset System

過去ドキュメントを発見、検索、読取、取込、書戻しするための基盤です。チーム既存資産をAIへ接続します。

### Storage / Repository / Document Output

Git、ファイルサーバー、SharePointなど、実際の出入り口です。AIはここへ直接好き勝手に書かず、定められた経路を通ります。

### Task Tracker Adapter

GitHub Issuesなどの外部課題管理とつなぐ部品です。今後Backlog等へ広げるための拡張点です。

![[Assets/Images/未整理メモ20261019/AI-DEの構成と全機能マップ（図解資料）の図05.svg]]

**重要:** 障害注入はProduct Protocolに載せず、Platform Test / internal test interfaceとして扱う。

この図の機能説明

### Runtime Invariants

絶対に壊してはいけない条件をプログラムで確認します。親より強い権限の子Agentが生まれていないか、などを見ます。

### Deterministic Boundary

同じ条件なら同じように進むべき範囲を明確にし、AI-DE自体の検証をしやすくする仕組みです。

### Fault Injection

わざと失敗やクラッシュを起こして、ハーネスが壊れにくいかを確認するテスト方法です。

### Evidence Verification

AIが『やりました』と言うだけでなく、証跡が本当に揃っているかを確認する検証です。

### Generated Artifact Test

生成・同期された成果物が、構造や由来の観点で壊れていないかを確認します。

![[Assets/Images/未整理メモ20261019/AI-DEの構成と全機能マップ（図解資料）の図06.svg]]

**Repository分割基準:** 「整理しやすいから」ではなく、独立したAuthority・Deployment・Lifecycleを持つかで判断する。

この図の機能説明

### AI-DEが持つAuthority

Runtime State、Gate判定、Human Decision反映、Task実行記録など、正式な開発状態の中心はAI-DEです。

### Orcaが持たないAuthority

Orcaは見せる・操作する側であり、正式状態や開発判断の正本を持ちません。

### Project固有の適用判断

どの規定が適用され、どのTaskが必要かといった案件固有判断はAI-DE側で持ちます。

### OpenCodexの位置づけ

OpenCodexは接続部品です。便利ですが、AI-DEの代わりに進捗やGateを管理する立場ではありません。

![[Assets/Images/未整理メモ20261019/AI-DEの構成と全機能マップ（図解資料）の図07.svg]]

**Core / 可視化 / 開発制御 **Knowledge / Requirements / 外部資産 **Governance / 権限 **実行 / Recovery **State / Verification **Model / Provider 破線枠 = 機能方向はあるが詳細・時期が未確定

**この7枚目の位置づけ:** 1〜6枚目が「責務境界・Architecture」を見るための図なのに対し、これは **AI-DEが何をする製品なのかを機能面から一望する図**です。 特に「開発知見を残して次に生かす」「Spider Viewで関係を可視化する」といった、Runtime構造図では省略していた機能も含めています。

この図の機能説明

### 要件定義・QA

AIと人間の対話から要求を固める機能です。質問、回答、根拠、追加調査を管理します。

### Governance・Gate・権限

規定や承認を守りながらAI開発を進める機能です。必須作業と提案作業の区別にも関係します。

### 計画・仕事の分解

必要なPhaseやTaskを組み立てる機能です。ここで組んだTaskがAI実行の対象になります。

### Execution Runtime

Taskを実際に動かす実行エンジンです。Worker、Tool、Providerを制御し、実行履歴も残します。

### State Store・Artifact・Evidence

実行状態と履歴の保存、成果物と証跡の参照管理を行う機能です。

### AI Model・Provider管理

利用するModelやProviderを管理し、Projectごとの設定に沿ってAIを実行可能にする機能です。

### 開発知見・Feedback Loop

今回の開発で得た情報を次へ生かす機能です。判断履歴や失敗例を資産化します。

### Feature Trace Graph / Spider View

機能・コード・ドキュメント・テストの関係を可視化し、理解負債を減らす機能です。

### 外部知識・資産・課題管理との連携

STK、Document Asset、Task Trackerなど、AI-DEの外側にある資産とつながる機能です。

### Platform Test・生成物検証

AI-DE自体の正しさと、作った成果物の妥当性を検証する機能です。

### Recovery・長時間自律実行

AIが長時間動いても壊れにくく、失敗後も追跡・復旧しやすくする機能です。

現時点の合意を可視化した作業用Architecture Artifact。製品名・Protocol名などの固有名詞は原語を残し、説明は日本語化。破線領域や未決事項は実装済みと誤認しないこと。
