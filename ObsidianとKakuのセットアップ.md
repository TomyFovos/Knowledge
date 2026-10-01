# Obsidian / Kaku セットアップ

このRepository自体をKaku Workspace兼Obsidian Vaultとして利用します。

## 一括セットアップ

WindowsでRepositoryをclone/pullしたあと、ルートで `setup-all.cmd` を実行します。
Obsidian側だけなら `setup-obsidian.cmd` を実行します。

セットアップ対象:

- Hearth
- Dataview
- Single HTML Export
- `Assets/Images` を画像保存先に設定
- `Workspace/Templates` をTemplatesフォルダに設定
- Kaku Windows x64 installer（setup-allのみ）

## Kaku

KakuではこのRepositoryのルートフォルダをそのままWorkspaceとして開きます。

主要なKnowledgeは `Notes/` に集約しています。
`Concept / Pattern / System / Idea` などの分類は今後Propertiesで持ちます。

## Obsidian Sync

Obsidianへログインし、Remote Vaultを作成または選択します。
スマホでも同じRemote Vaultを開きます。

## Hearth

初回Setup Wizardを完了し、`Workspace/Dashboard/ナレッジダッシュボード.md` または各Baseをカードとして配置します。
Hearthのレイアウトが固まったらpluginのdata.jsonをGit管理して再利用できます。

## Jev

Jev用Properties契約は `Workspace/System/ナレッジのプロパティ定義.md` を参照してください。
Jevは原則としてNotesをフォルダ移動せず、Properties・Links・推薦情報を更新します。
