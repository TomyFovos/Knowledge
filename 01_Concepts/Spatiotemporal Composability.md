# Spatiotemporal Composability（時空間合成可能性）

## 概要

実行中の system から、一つの Component だけを安全に追加・削除・置換できるだろうか。

単に code を差し替えるだけなら plugin system や HMR でもできる。しかし、その Component が登録した event、確保した resource、書き換えた shared state まで回収し、さらに依存していた Component だけを正しい順序で停止・再起動させるとなると、問題は別物になる。

*A Programming Paradigm for Spatiotemporal Composability* は、この問題を二つの直交する軸へ分ける。

- **Temporal Composability**：Component を外したとき、その Component が環境に残した Effect を安全に撤回できること
- **Spatial Composability**：Component 間の dependency を宣言し、provider の追加・削除・置換に応じて lifecycle を再調整できること

論文は古典的な Effect / Coeffect の概念を compile-time analysis から runtime mechanism へ持ち上げ、この二つを同じ Context 上に統合する。

重要なのは「plugin を unload できる」という個別機能ではない。

**Component が環境に対して何を変えるか、何を必要とするか、そしてその操作が誰の lifecycle に属するかを runtime が追跡できる状態にする**ことが、この paradigm の中心である。

## ナレッジ構成

この論文は一枚の要約に押し込まず、再利用できる単位へ分割している。

### [[Revertible Effects]]

副作用を起こすときに inverse も同時に返し、runtime がそれを追跡・合成する。Component unload 時に、その Component の寄与だけを回収する Temporal Composability の中心概念。

### [[Reactive Coeffects]]

Component が必要な dependency を宣言し、Context の変化に応じて activation / deactivation を駆動する。Isolation、Interception、provider withdrawal ordering もここに含む。

### [[Context Paradigm]]

Effect と Coeffect を一つの Context に統合する考え方。Functional な traceability と imperative な ergonomics の中間を狙い、Component と外界の相互作用を同じ mediation layer に集約する。

### [[Dynamic Component Lifecycle]]

Component を dependencies / provisions / effects の三つ組として扱い、実行時 instance を fiber として lifecycle 管理する。Transition、withdrawal guard、failure、progress、confluence など system-wide guarantee を扱う。

### [[System Boundary and Recoverability]]

どこまでの Effect を本当に rollback できるのかを決める境界。Resource acquisition と external emission の違い、compensation、sandbox、OS との co-design を整理する。

### [[Cordis]]

論文の形式モデルを TypeScript で実装した meta-framework。`ctx.effect`、dependency resolution、Component Loader、Koishi の production case study を扱う。

### [[Transactional Hot Module Replacement]]

Revertible Component lifecycle を利用して HMR を transaction として扱うパターン。変更 module の分類、stale Component の検出、failure 時の rollback を整理する。

## この論文が self-evolving agent harness に重要な理由

論文は plugin system と並んで **self-evolving agent harness** を motivating example に置いている。

Agent harness は tool suite、execution environment、permission / sandbox、session state、memory、subagent orchestration など多くの runtime Component を持つ。将来的に Agent 自身がこれらを生成・差し替えるようになると、変更のたびに process 全体を restart する設計では、process-local state や in-flight task が失われる。

さらに dependency topology も頻繁に変わるため、単純な code replacement だけでは dependent Component の整合性を保てない。

この意味で、

```text
自己変更できること
        ↓
変更を安全に撤回できること
        ＋
変更後の dependency topology を再構成できること
```

は別の問題である。

Spatiotemporal Composability は、後ろ二つに formal foundation を与えようとしている。

ただし、self-evolving agent harness への適用は論文中では future validation として位置づけられており、[[Cordis]] / Koishi と同程度に実証された結果ではない。

## 参考資料

- Yifan Shi, Wei Zhang, Tianyi Cui, *A Programming Paradigm for Spatiotemporal Composability*, Peking University / DeepSeek-AI.
- 原文PDF: `[[09_References/Spatiotemporal Composability/A Programming Paradigm for Spatiotemporal Composability.pdf]]`
