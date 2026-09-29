# Obsidian / Kaku セットアップ

このRepository自体をObsidian Vaultとして利用します。

## 採用構成

- Obsidian: 閲覧、手編集、スマホ、Properties、Bases
- Hearth: Dashboard / Home
- Dataview: Basesで足りない複雑な抽出
- Single HTML Export: 共有用の自己完結HTML
- Kaku: 同じMarkdownをAI/Agentで編集
- Obsidian Sync: PCとスマホの同期
- GitHub: 履歴・バックアップ・Agent操作
- Jev（今後追加）: 分類・整理・推薦。Propertiesのみ更新

Markdown + assets がSSOTです。

## 一括セットアップ

WindowsでRepositoryをclone/pullしたあと、ルートで setup-all.cmd を実行します。
Obsidian側だけなら setup-obsidian.cmd を実行します。

setup-obsidian.cmd はHearth / Dataview / Single HTML Exportの最新版を
各公式GitHub Releaseから取得し、必要なフォルダを作ります。
既存Knowledgeノートは移動・書き換えしません。

setup-all.cmd はそれに加え、Kakuの公式Windows x64 installerを取得して起動します。
KakuではこのRepositoryルートをそのまま開いてください。

## 初回だけ手作業

### Obsidian Sync
Obsidianへログインし、Remote Vaultを作成/選択します。
スマホでも同じRemote Vaultを開きます。

### Hearth
初回Setup Wizardを完了し、_Dashboard/Home.md または各Baseをカードとして配置します。
レイアウトが固まったらHearthの data.json をコミットすれば他端末にも再利用できます。

## Dashboard

_Dashboard/ に以下を用意します。

- Inbox.base
- FollowUps.base
- Recommendations.base
- Active.base
- Home.md

Jev用Properties契約は _system/KNOWLEDGE_SCHEMA.md を参照してください。
