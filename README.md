# Knowledge

Kaku・Obsidian・AI Agent・Jevから同じMarkdownを扱うための、local-firstなナレッジWorkspaceです。

Kakuは特定のフォルダ構造を要求せず、Markdownが入ったフォルダをそのままWorkspaceとして扱います。
そのため、このRepositoryでは知識の種類をディレクトリで細かく分けず、Properties・リンク・タグで分類します。

## ディレクトリ構造

```text
Knowledge/
├─ Inbox/                 # 未整理のメモ・一時投入
├─ Notes/                 # すべてのKnowledgeノート
├─ Sources/               # PDFなどの外部資料
├─ Assets/                # 画像・添付ファイル
│  ├─ Images/
│  └─ Files/
├─ Workspace/
│  ├─ Dashboard/          # Obsidian Bases / Hearth用
│  ├─ Templates/          # Obsidian Templates
│  └─ System/             # Jev/Agentとの契約・構成
├─ .obsidian/
├─ .github/
└─ README.md
```

## 原則

- Markdown + AssetsをSSOTにする。
- KakuとObsidianは同じRepositoryを直接開く。
- Concept / Pattern / System / Idea / Experiment / Decision / Lessonなどはフォルダではなく `type` Propertyで表す。
- 調査中・採用済み等は `status` Propertyで表す。
- ProjectやTopicもProperties/リンクで持つ。
- Jevはノートを分類フォルダ間で移動するのではなく、Properties・リンク・推薦情報を更新する。
- 外部資料だけはMarkdownと分離し `Sources/` に置く。

## 基本フロー

```text
思いつく / スマホでメモ
        ↓
      Inbox
        ↓
Kaku / Agent / Jev が整理
        ↓
      Notes
        ↓
Properties・Links・Backlinksで関係付け
        ↓
Obsidian + Hearth Dashboardで閲覧
```

## ノートの分類

主な `type` 候補:

- `Concept`
- `Methodology`
- `Pattern`
- `System`
- `Idea`
- `Experiment`
- `Decision`
- `Lesson`
- `Reference`

主な `status` 候補:

- `Idea`
- `Researching`
- `Experimenting`
- `Adopted`
- `Rejected`

既存ノートにPropertiesがなくても有効です。Jev/Agent側で段階的に補完します。

## Kaku

KakuではRepositoryルート `Knowledge/` をWorkspaceとして開きます。
別コピーやImportは不要です。

Kakuは主に以下に使います。

- AI/Agentによる既存ノート編集
- 変更diffの確認・採用/却下
- Links / Backlinks / 関連ノートを使ったContext収集
- 複数案のbranching chat
- Knowledge全体の整理・リファクタリング

## Obsidian

Obsidianでも同じRepositoryルートをVaultとして開きます。
Hearth・Bases・Dataviewで閲覧とDashboardを担当し、Obsidian Syncでスマホと同期します。

セットアップ手順は `SETUP_OBSIDIAN.md` を参照してください。
