# AI-DE エージェントハーネスの構成と設計思想

## 1. この文書の目的

AI-DEでは、エージェントの動きを単一のプロンプトファイルだけで制御しようとしていない。

エージェントへ渡す指示、どの指示をどの用途へ適用するかというProfile、Agent Harness固有の設定、実行時の権限と状態遷移の強制を分離している。

この文書は、その構成と設計理由を共有するための説明資料である。

記載内容は「日本ハーネス_統合引継ぎ資料.md」の第2章、第6章、第16章を基礎としている。

引継ぎ資料は2026年9月22日時点の会話記録を統合したものであり、現在のRepository実物を改めて監査した結果ではない。

## 2. 全体像

AI-DEのエージェント制御は、大きく二つに分かれる。

一つは、エージェントへ「何をするか」「どう振る舞うか」を伝えるInstruction層である。

もう一つは、エージェントが指示を無視した場合でも、権限外の正式操作や状態変更を成立させないRuntime統制層である。

```text
Canonical Instructions
  docs/ai-instructions/*
          +
Profile Definition
  config/ai-instructions/profiles.yaml
          |
          v
      Registry
          |
          v
       Renderer
          |
          +--> AGENTS.md
          |
          +--> Harness向け generated surfaces
          |
          +--> .github/ai-de/generated-instructions-index.json

Harness固有拡張
  .claude/rules/*
  .claude/skills/*
  .claude/agents/*
  .claude/settings.json

                    ↓ 実行時

AI-DE Execution Control Plane
  Plan / Task Graph
  Execution Packet
  Capability / Permission
  Attempt / Operation
  Gate
  Artifact / Evidence
  Recovery / Reconciliation
```

Instructionは行動を誘導する。

Runtimeは許可された作用だけを成立させる。

この二つを同一視しないことが、現在の構成を理解するうえで最も重要である。

## 3. 設計思想

### 3.1 指示だけをSecurity Boundaryにしない

LLMへのInstructionは必要だが、それだけでは強制力にならない。

AI-DEはExecution Control Planeとして、Task、Attempt、Operation、Gate、Artifact、Evidence、Recovery、Reconciliationを管理する。

Agent HarnessはInstructions、Skills、Tools、Session、Permissionsを担当するが、AI-DEの長寿命Execution Stateや正式な状態遷移のAuthorityは持たない。

したがって、「AGENTS.mdに禁止と書いたから安全」という設計にはしない。

禁止すべき作用は、Capability、Guard、Gate、State transitionなどRuntime側でも制約する。

### 3.2 Authority Conservation

下位Agentや子Agentは、上位から渡された権限を自分で広げない。

Worker数が増えても、sub-agentが増えても、判断権限まで増えたことにはしない。

Agent Treeそのものを仕事の正本にも置かない。

仕事の正本はPlanとTask Graphに残し、Agentが新しい仕事の必要性を発見した場合は、勝手に正式Taskを増殖させず、上位の管理側へ戻す構造を採る。

### 3.3 意味判断と決定的処理を分ける

AIは分析、提案、意味理解を担当できる。

一方、状態遷移、契約検証、既知規則からの判定、revision確認、digest確認のような決定的処理はコードで扱う。

LLMの推測を、そのまま正式な依存関係や完了状態へ昇格させない。

この考え方はInstruction生成にもつながっている。

人間が管理すべき正本と、Agentが読むために生成された表示面を分離する。

### 3.4 正本を一つにし、生成物を第二の正本にしない

AI-DEでは、同じ意味のInstructionを複数のAgent Harness向けファイルへ人手で複製し続ける構成を避ける。

共通の内容は `docs/ai-instructions/*` に置き、適用条件を `config/ai-instructions/profiles.yaml` で管理し、そこから必要なSurfaceを生成する。

生成されたファイルはAgentが読むためのSurfaceであって、独立した正本ではない。

生成物を直接修正した場合やSourceとの差分が生じた場合は、driftとして検出する方向で設計されている。

### 3.5 Agent Harness固有機能だけを固有領域へ置く

Claude、Codex、OpenCode、CopilotなどのAgent Harnessは、それぞれ固有の機能を持つ。

AI-DEは、それらをすべて自前で再実装しない。

共通ルールは共通Instructionへ置き、本当に特定Harnessだけに意味があるルール、Skill、sub-agent定義、設定だけをHarness固有領域へ残す。

Claude向けでは、その境界が `.claude/rules/*`、`.claude/skills/*`、`.claude/agents/*`、`.claude/settings.json` として表現されている。

### 3.6 Self-developmentとConsumerを分ける

日本ハーネス自身を開発するときの作業と、日本ハーネスを使って顧客Projectを開発するときの作業では、必要なInstructionが異なる。

以前は、Consumer向けのPhase強制、要件質問、UIレビュー、効果測定などが自己開発にも混入し、作業を重くしていた。

そこで、Instruction Sourceを消すのではなく、Profileと読込経路を分けた。

Self-developmentを軽量化しても、RuntimeのSecurity、Gate、Evidenceを弱めたことにはしない。

これはInstruction適用範囲の分離であって、安全条件の撤廃ではない。

### 3.7 Evidence over Assertion

Agentが「実行した」「レビューした」「通った」と発言したこと自体を完了根拠にはしない。

対象revision、実行結果、Artifact、Evidence、receiptなどを確認可能な形で残す。

Instructionは作業者への指示であり、Evidenceは実際に何が起きたかを確認するための記録である。

両者を分けることで、流暢な報告を正式事実へ読み替えない。

### 3.8 Adapt, Don’t Impose

AI-DEは、既存Projectの言語、DB、文書形式、開発工程をAI-DE都合で一律に統一することを目的にしない。

Agent Harnessについても同じで、Codex、Claude系、OpenCodeなどの既存能力を利用し、必要なCapabilityを契約で接続する。

一つの巨大な自製Agent Harnessへ集約するより、交換可能なHarnessを利用しながら、Execution ControlだけをAI-DEが保持する方向を採る。

## 4. 主なファイルと役割

| ファイルまたはパス | 役割 | 位置付け |
| --- | --- | --- |
| `AGENTS.md` | Project内でAgentが読む共通入口 | Self-developmentとConsumerの共通入口 |
| `docs/ai-instructions/*` | 共通InstructionのSource群 | Instruction内容の正本 |
| `config/ai-instructions/profiles.yaml` | InstructionをどのProfileへ適用するかを定義 | 適用条件の正本 |
| Registry | SourceとProfileを解決する論理層 | 生成前の選択処理 |
| Renderer | 選択されたInstructionからSurfaceを生成する論理層 | 決定的な生成処理 |
| generated surfaces | 各Agent Harnessが実際に読むための生成物 | 正本ではない |
| `.github/ai-de/generated-instructions-index.json` | path、source、category、profile、owner、applicability等のInventory | 管理用Index |
| `.claude/rules/*` | Claude固有ルール | Harness固有 |
| `.claude/skills/*` | Claude固有Skill | Harness固有 |
| `.claude/agents/*` | Claude固有sub-agent定義 | Harness固有 |
| `.claude/settings.json` | Claude固有設定 | Harness固有 |
| `CLAUDE.md` | 以前のClaude向け共通入口 | 共通Surfaceとして退役 |
| `docs/ai-instructions/エントリポイント-Claude.md` | 以前のClaude専用共通Source | 共通Sourceとして廃止 |

引継ぎ資料では、論理構成を `docs/ai-instructions/*` と `config/ai-instructions/profiles.yaml` からRegistry、Rendererを経てgenerated surfacesとindexを作る形として説明している。

RegistryやRendererの具体的な実装ファイル名までは、今回参照した統合引継ぎ資料には記載されていない。

共有時に実装ファイル名まで必要であれば、現行Repositoryを別途確認する必要がある。

## 5. なぜAGENTS.mdを共通入口にしたのか

Self-developmentとConsumerの双方で、共通入口は `AGENTS.md` に統一する方針が採用された。

目的は、Agent Harnessごとに共通Instructionを複製し、内容が徐々にずれる状態を避けることにある。

Claude向けだから `CLAUDE.md`、別Harnessだから別の共通入口、という形で同じ規範を複数管理すると、どのファイルが正しいのか判断しにくくなる。

そこで、共通部分は `AGENTS.md` を入口とし、Claudeにしか存在しない機能だけを `.claude/*` に残す。

この境界により、「共通規範」と「Harness固有能力」を別々に更新できる。

## 6. CLAUDE.mdを退役させた理由

Consumerだけ `CLAUDE.md` を互換用に残す案も検討されたが、最終的には採用されなかった。

`CLAUDE.md` を共通入口として残すと、`AGENTS.md` と二つの入口が存在することになる。

二つの入口が同じ意味を持つ限り、同期、鮮度確認、衝突時の優先順位という新しい管理問題が生まれる。

そのため、generated `CLAUDE.md` は退役させ、Claude固有の内容だけを `.claude/*` へ残す構成へ整理した。

ただし、由来不明のuser-owned `CLAUDE.md` を名前だけで自動削除する設計にはしていない。

既知の旧生成物と確認できない場合は、衝突として保持し、安全側へ倒す。

## 7. InstructionとRuntime Enforcementの境界

| 項目 | Instruction層 | Runtime統制層 |
| --- | --- | --- |
| 作業方針 | 伝える | 必要に応じて検証する |
| Coding rule | 伝える | 一部は機械検証できる |
| 使用してよいTool | 説明できる | Capabilityで制限する |
| 正式なTask | 説明しない | Plan／Task Graphが所有する |
| sub-agentの自由な仕事追加 | 禁止を伝えられる | 正式Task化を管理側へ限定する |
| 外部作用 | 注意事項を伝える | Operationとして追跡する |
| 状態遷移 | 条件を説明できる | Core／Gateが強制する |
| 完了判定 | Agentが報告できる | Evidenceを確認して決定する |
| 失敗後の再試行 | 方針を伝えられる | Attempt／Recovery／Reconciliationで管理する |
| Authority | 境界を説明する | 上位から与えられた範囲を超えないよう強制する |

この境界により、プロンプトの品質とシステムの安全性を同じ問題として扱わずに済む。

Instructionが多少誤解されても、正式状態や外部作用まで無条件に成立させない構成を目指している。

## 8. Profile方式を採る理由

Instructionの有無だけでなく、「誰が、どの用途で、どの指示を読むのか」を管理する必要がある。

そこで `profiles.yaml` を使い、Self-developmentとConsumerなどの適用範囲を分ける。

これにより、共通Instruction Sourceを維持しながら、用途ごとに読込対象を変えられる。

ProfileはSecurity Floorを解除するためのものではない。

Self-development ProfileでConsumer向け工程を減らしても、製品Runtimeが持つSecurity、Gate、Evidenceの責務は残る。

## 9. 生成物の鮮度管理

生成されたInstruction Surfaceは正本ではないため、Sourceと一致していることを確認できなければならない。

現在の設計では、指示鮮度の確認を永続的なSHA一覧だけへ依存させず、expected canonical contentとactual contentの直接比較を使う方向へ整理された。

`.github/ai-de/generated-instructions-index.json` は、Instruction本文の真正性そのものを決める台帳ではなく、どのSourceがどこへ適用されるかを追跡するInventoryとして扱う。

一方、Execution Packet、Artifact、Evidence、Attestation、署名、provenance、request／revision bindingなど、信頼境界で必要なdigestまで廃止するわけではない。

Instruction鮮度とRuntime Evidenceでは、digestを必要とする理由が異なる。

## 10. この設計で避けようとしている状態

| 避けたい状態 | 採用している対策 |
| --- | --- |
| Agent Harnessごとに同じルールを手作業で複製する | Canonical SourceからSurfaceを生成する |
| `AGENTS.md` と `CLAUDE.md` が第二の正本になる | 共通入口を `AGENTS.md` に統一する |
| Claude固有設定へ共通ルールが混入する | `.claude/*` には固有機能だけを残す |
| Consumer向けの重い工程が自己開発にも常時かかる | Profileと読込経路を分ける |
| Agentが自分でTaskを増殖させる | Plan／Task Graphを仕事の正本にする |
| Agentの自己申告だけで完了する | ArtifactとEvidenceを確認する |
| 指示に書いた禁止事項をSecurity Boundaryと誤認する | Capability、Gate、Guard、State transitionで強制する |
| Agent Harness内部機能をAI-DEで全部再実装する | 既存HarnessのCapabilityを利用する |
| 生成物の直接編集が正本へ逆流する | Sourceとgenerated surfaceを分離しdriftを検出する |

## 11. 設計上の責務分担

AI-DEは、Agentそのものを置き換える製品ではない。

AI-DEは、外部で確定したIntentと委譲権限の下で、交換可能なAgent Harnessへ仕事を委任し、Agent Sessionを越えてExecution StateとEvidenceを保持するExecution Control Planeである。

Agent HarnessはAgent loop、Session、Tools、内部sub-agent、モデル呼出しなどを担当する。

ArthurはGoal、Requirement、Acceptance Criteria、意味DecisionなどのAuthorityを持つ。

Japan-HarnessはProvider、Profile、BindingなどCompositionの正本を持つ。

この分離があるため、Instructionファイルの構成だけを見てAI-DE全体のAuthorityモデルを判断することはできない。

## 12. 現在の確認範囲

この文書で確定扱いしているのは、統合引継ぎ資料に記録された設計と受入履歴である。

`AGENTS.md` をSelf-developmentとConsumerの唯一の共通入口にする決定、generated `CLAUDE.md` の退役、Claude固有機能を `.claude/*` へ限定する整理、Profile分離は、引継ぎ資料上で受入済みとして記録されている。

一方、Registry、Renderer、generated surfacesの現在の具体的な実装ファイル一覧は、この統合引継ぎ資料だけでは確定できない。

また、Claude CodeのAGENTS.md fallbackに関する当時のRuntime確認には未検証事項が残っており、外部製品の現在仕様をこの文書で再検証したものではない。

現行Repositoryの実ファイルを共有資料へ固定したい場合は、Repositoryの最新revisionに対する棚卸しを別途行う。

## 13. 共有時に伝えたい要点

AI-DEのエージェントハーネスは、「良いプロンプトを書けばAgentを制御できる」という発想では作られていない。

Instructionは正本から生成し、用途ごとのProfileで適用範囲を分け、Agent Harness固有機能は固有領域へ閉じ込める。

そのうえで、正式な仕事、権限、状態遷移、外部作用、完了判定はAI-DEのExecution Control Planeで管理する。

つまり、**Instructionで行動を誘導し、RuntimeでAuthorityと作用を制約し、Evidenceで結果を確認する**という三層でAgentを扱う設計である。

この分離によって、Agent Harnessを交換してもAI-DEのExecution Stateと統制を維持しやすくし、同時に各Harnessが既に持つ能力を再利用できる。

## 14. 参照元

本書の主な根拠は、以下のProject資料である。

`日本ハーネス_統合引継ぎ資料.md`

参照箇所は、第2章「判断を支える設計原則」、第6章「AI-DEに残す開発・実行モデル」、第16章「Self-development／Consumerの分離」である。

特にInstruction構成については、第16.2節と第16.5節の記録を基礎としている。
