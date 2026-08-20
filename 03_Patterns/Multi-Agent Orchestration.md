# Multi-Agent Orchestration

## 概要

**Multi-Agent Orchestration**は、一つのAgentですべてを処理する代わりに、複数のAgentへ役割を分け、委譲、並列実行、結果統合を行う設計パターンである。

ただし、Agentを増やせばよいわけではない。

OpenAIは、まずSingle-Agentの能力を最大化し、複雑な条件分岐やTool選択の失敗が増えたときにMulti-Agentへ分割する段階的な導入を勧めている。

Anthropicも、Multi-Agentが特に有効なのは、複数の独立した方向を同時に探索できる問題、単一Context Windowを超える情報量を扱う問題、多数のToolを使う問題だとしている。

逆に、Agent間で同じContextを常時共有する必要がある問題や、依存関係が強く並列化しにくい問題には向かない。

## Multi-Agentへ分割する条件

OpenAIは、Single-AgentにToolを追加しながら能力を広げる方が、評価と保守を単純に保ちやすいとしている。

Multi-Agentを検討する目安は、Agent数ではなく、一つのAgentに集めた責務が判断を不安定にしているかどうかである。

具体的には、次のような症状が分割の合図になる。

- Promptに多数の条件分岐が入り、論理を追いにくくなった。
- Tool名や役割が重複し、Agentが誤ったToolを選ぶ。
- Toolの説明やParameterを改善しても選択精度が上がらない。
- 独立した複数の探索や処理を並列化できる。
- 一つのContext Windowへ情報を集め続けることがボトルネックになる。

AnthropicのResearch systemでは、Lead AgentとSubagentを分けた構成が、特にbreadth-firstな調査で有効だった。

Anthropicの内部評価では、Claude Opus 4をLead Agent、Claude Sonnet 4をSubagentに使うMulti-Agent構成が、Single-AgentのClaude Opus 4を90.2%上回ったとしている。

この数値はAnthropicの内部Research evalの結果であり、Multi-Agent一般の性能向上率として扱うものではない。

## 二つの基本パターン

OpenAIは、Multi-Agentの構成を大きく**Manager**と**Decentralized**の二つに分けている。

### Manager

**Manager Pattern**では、中央のAgentがWorkflowの制御を持ち、専門AgentをToolとして呼び出す。

中央Agentは、どのAgentへ何を任せるかを決め、返ってきた結果を統合する。

AnthropicのResearch systemも、このManager Patternに近いOrchestrator-Worker構成を採用している。

```text
User
  ↓
Lead / Manager Agent
  ├─ Subagent A
  ├─ Subagent B
  └─ Subagent C
  ↓
Synthesis
  ↓
Result
```

一つのAgentだけがUserとの対話と最終統合を担当したい場合に適している。

### Decentralized

**Decentralized Pattern**では、中央のManagerを置かず、Agent同士がHandoffによってWorkflowの制御を引き渡す。

```text
Triage Agent
  ↓ handoff
Specialist A
  ↓ handoff
Specialist B
```

各Agentが対等に近い立場で、自分の専門領域に応じて次のAgentへ処理を渡す。

中央で一貫して結果を合成する必要がなく、担当領域ごとにAgentがUserとの対話を引き継げるWorkflowに向く。

## Orchestratorの委譲契約

Anthropicは、Lead AgentがSubagentへ短い指示だけを渡すと、探索範囲が重複したり、必要な領域が抜けたりしたと報告している。

委譲時には、少なくとも次を明示する。

- **目的**：何を調べる、または何を処理するのか。
- **境界**：他のAgentと何を分担し、どこまでを担当するのか。
- **出力形式**：何をどの形で返すのか。
- **Tool**：どのToolや情報源を優先するのか。
- **完了条件**：どこまで進めれば十分なのか。

委譲の品質が低いと、Agent数を増やしても探索量が増えるだけで、分業にはならない。

## 処理量は問題の複雑さに合わせる

Anthropicは、Agent自身に必要な調査量を完全に判断させると、簡単な問いにも過剰なSubagentやTool callを使う問題が起きたとしている。

そのため、問題の複雑さに応じてAgent数とTool call数の目安をPromptへ与えている。

例として、単純なFact findingは1 Agentと少数のTool call、比較問題は数Agent、複雑なResearchは10を超えるSubagentまで使うという段階を設けている。

ここで固定すべきなのは厳密なAgent数ではなく、**仕事量を問題の価値と複雑さに合わせる規律**である。

Anthropicの実測では、通常のAgentはChatより約4倍、Multi-Agent systemはChatより約15倍のTokenを使ったとしている。

したがって、Multi-Agentは性能上の利益だけでなく、その仕事が追加Costに見合うかで判断する必要がある。

## 並列化はMulti-Agentの主要な利点

AnthropicのResearch systemでは、Lead Agentが3〜5のSubagentを並列起動し、Subagent自身も複数のToolを並列実行する構成へ変更した。

この二段階の並列化によって、複雑なResearch taskの所要時間を最大90%削減できたとしている。

Multi-Agentの利点は「専門家が増える」ことだけではない。

別々のContext Windowを持つAgentへ探索を分散し、同時にToken budgetとTool実行を増やせることにある。

## Contextを分割して最後に圧縮する

Anthropicは、検索を大量の情報から重要部分へ圧縮する仕事として捉えている。

各Subagentは独立したContext Windowで探索し、必要な情報だけをLead Agentへ戻す。

この構成には二つの効果がある。

- 一つのContext Windowへ全探索履歴を詰め込まずに済む。
- 異なるAgentが独立した探索経路を持つため、同じ探索方針への過度な依存を減らせる。

長時間動くAgentでは、Context上限に近づく前に完了済みの作業を要約し、外部Memoryへ保存する方法も使われている。

Anthropicはさらに、Subagentの大きな成果物をLead Agent経由で全文転送せず、File systemなどの外部Artifactへ保存し、参照だけを返す方法を紹介している。

この方法は、中継のたびに情報が削られることとToken overheadを減らせる。

## Tool設計はAgent設計の一部である

両資料とも、Agentの能力をModelだけで決めていない。

OpenAIはAgentの基本要素をModel、Tools、Instructionsの三つとして整理している。

Anthropicは、Tool interfaceをHuman Computer Interfaceと同じ程度に重要な設計対象として扱っている。

Toolの説明が曖昧だと、Agentは存在するToolを使わずに遠回りしたり、誤ったToolを選んだりする。

Toolには、役割が重複しない名前、明確な説明、Parameter、利用条件を与える。

Agentを増やす前にToolの境界を整理する必要がある。

## 評価は経路ではなく結果を見る

Multi-Agent systemは、同じ入力でも毎回同じ手順を通るとは限らない。

Anthropicは、固定した正解経路との一致ではなく、最終結果と妥当なProcessを評価する方法を採用している。

Research outputでは、次の基準をRubricとしてLLM-as-judgeを使っている。

- factual accuracy
- citation accuracy
- completeness
- source quality
- tool efficiency

一方で、自動評価だけではSource selectionの偏りや特殊なQueryでのHallucinationを拾い切れないため、人間によるTestも残している。

Anthropicは初期段階から約20件の実利用に近いQueryで評価を始め、Prompt変更の影響を早く確認した。

Agentが外部状態を書き換えるWorkflowでは、各Turnの手順より、最終状態が正しいかを評価し、必要なら中間Checkpointごとの状態変化を検証する。

## Productionでは状態管理が中心課題になる

長時間動作するAgentはStatefulであり、小さな失敗が後続の判断へ連鎖する。

Anthropicは、障害時に最初からやり直すのではなく、Checkpointから再開できる実行基盤を構築している。

Model自身にTool failureを伝えて別経路へ切り替えさせる柔軟性と、RetryやCheckpointのような決定論的なSafeguardを組み合わせている。

Non-deterministicなAgentをDebugするには、結果だけでなく、Tool選択、探索Query、Agent間のInteractionを追えるTracingが必要になる。

Anthropicの現在のResearch systemでは、Lead AgentがSubagentの完了を同期的に待つため、一つのSubagentが遅れると全体が止まるという制約も残っている。

非同期化すれば並列性を上げられるが、Result coordination、State consistency、Error propagationが新しい問題になる。

## GuardrailsとHuman Handoff

OpenAIは、Guardrailを一つのFilterではなく、複数の防御を重ねるLayered defenseとして扱っている。

対象には、Prompt injection、Relevance、PII、Moderation、Tool risk、Output validationなどが含まれる。

特にToolは、Read-onlyかWriteか、操作が可逆か、必要Permission、金銭的影響などでRiskを評価し、高Riskな操作では追加CheckやHuman approvalを挟む。

Human interventionが必要になる代表的な条件は二つある。

- Retryや失敗回数が閾値を超えた。
- 不可逆、高額、機密性の高いActionを実行しようとしている。

Multi-Agent化しても、制御不能になった処理をAgent間で回し続けるのではなく、人間へ制御を返すExitを持たせる必要がある。

## 選択の目安

```text
まず Single-Agent
  ↓
Prompt / Tool設計を改善しても複雑さが残るか？
  ├─ No  → Single-Agentを維持
  └─ Yes
       ↓
独立した処理を並列化し、中央で統合したいか？
  ├─ Yes → Manager / Orchestrator-Worker
  └─ No
       ↓
担当AgentがUserとの対話ごと引き継いでよいか？
  ├─ Yes → Decentralized / Handoff
  └─ No  → 責務分割を見直す
```

Multi-Agentは、Single-Agentの限界を隠すために導入するものではない。

一つのAgentに集めた責務を整理したうえで、それでも独立したContext、専門性、並列性が必要な部分だけを分割する。

## 関連

- [[Context Paradigm]]
- [[Knowledge Graph for AI Agents]]
- [[Software Engineering]]

## 参考資料

- Anthropic, `How we built our multi-agent research system`
- https://www.anthropic.com/engineering/multi-agent-research-system
- OpenAI, `A practical guide to building agents`
- https://cdn.openai.com/business-guides-and-resources/a-practical-guide-to-building-agents.pdf
