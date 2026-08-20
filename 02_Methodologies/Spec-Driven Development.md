# Spec-Driven Development

## 概要

**仕様駆動開発（Spec-Driven Development, SDD）**は、AI Coding Agentに実装を任せる前に、要求、設計、タスクを文書として明示し、その文書を開発の足場にする方法である。

元資料では、AI時代の仕様駆動開発を、2025年7月にKiroの発表とともに広まった「実装前に仕様を作る」ワークフローとして位置づけている。

ただし、仕様駆動開発の価値は「仕様書を書くこと」そのものにはない。

元資料が整理する実用上の役割は、次の二つである。

- **AIワークフロー**：要求から設計、タスクへ進む順序をAgentに与える。
- **長期記憶**：決定した内容を文書として残し、将来の変更や保守でもAgentと人間が参照できるようにする。

## 共通するワークフロー

Kiro、Spec-Kit、OpenSpecは名称や成果物が異なるが、元資料では核となる流れを「仕様 → 設計 → タスク化」と整理している。

```text
Kiro      : Requirements → Design → Tasks
Spec-Kit  : Specify → Plan → Tasks
OpenSpec  : Proposal → Specs → Design → Tasks
```

この構造の役割は、Agentに詳細な手順を固定することより、実装に入る前に未決事項を外へ出し、人間が確認できる形にすることにある。

## Specの保持方法

元資料は、Martin Fowlerの記事で紹介された分類を使い、Specの扱いを三つに分けている。

- **spec-first**：最初にSpecを書いて開発し、タスク完了後はSpecを破棄する。
- **spec-anchored**：タスク完了後もSpecを保持し、変更や保守に合わせて更新し続ける。
- **spec-as-source**：Specを原本とし、コードはSpecから生成する。

元資料では、現時点の実務ではspec-firstとspec-anchoredが中心で、spec-as-sourceは一般的な運用には至っていないと整理している。

## Spec-firstはPlan Modeへ吸収される

元資料が「仕様駆動開発の消費期限」と呼ぶ理由の一つは、spec-firstが独立した方法論ではなくなりつつあることにある。

Coding AgentのPlan Modeは、調査、質問、計画、タスク化を経て実装する方向へ進化しており、spec-firstが担っていた「実装前に考えてから着手する」という機能を標準機能として取り込みつつある。

そのため、短期的な計画だけが目的なら、専用のSpec形式を維持する必然性は下がる。

設計判断や用語を保存するだけなら、用語集、ADR、LLM Knowledge Baseのような別の記録方法も選べる。

## チーム開発では別の価値が残る

一方で、チーム開発ではAgentの自走性能が上がるほど、人間側の理解がボトルネックになる。

元資料では、コードの実装と「なぜそのように動くのか」というチームの共通理解が離れる状態を、codebase cognitive debtやComprehension Debtの議論と結び付けている。

Agentが大量の変更を生成できても、チームがその変更を理解してレビューできなければ、生成速度はそのまま開発速度にはならない。

ここで必要になるのは、AgentだけのためのContext Engineeringではない。

人間が変更理由を追い、合意し、レビューするための形式とワークフローも必要になる。

仕様駆動開発は、この「人間のためのContext」を比較的わかりやすい形で提供する。

## AI駆動開発の「型」として使う

元資料では、チームへAI駆動開発を導入する際に、AI-DLC、Skillsの組み合わせ、仕様駆動開発を比較している。

AI-DLCは開発プロセス全体を扱える一方で、既存プロセスや会社標準との対応まで含めると導入が重くなりやすい。

個別Skillsの組み合わせは柔軟だが、チーム全員が共有するワークフローとしては型が弱い。

その中間として、仕様駆動開発は次の三つを同時に提供する。

- **開発の規律**：実装前に要求と設計を確認する。
- **理解の形式**：変更の意図と判断を文書へ残す。
- **レビューのワークフロー**：仕様、実装、検証を対応付ける。

この用途では、最終形として固定するより、チームがAI駆動開発に慣れるまでの「守」として使う方が適している。

## OpenSpecを選ぶ判断

元資料の事例では、Agentを固定しないことを前提にKiroのSpec機能を候補から外し、Spec-KitとOpenSpecを比較している。

Spec-Kitは生成される文書が大きくなりやすく、人間の認知負荷が高いと判断された。

そのため、より軽量なOpenSpecを採用している。

特に次の二つの操作を評価している。

- `/opsx:verify`：仕様と実装の一次チェックを行う。
- `/opsx:archive`：実装完了後のSpecをarchiveし、メインの仕様へ同期する。

選定基準は「最も多機能なもの」ではなく、チームが読み続けられる量に抑えながら、仕様と実装の対応を維持できることである。

## 仕様駆動開発を破るタイミング

仕様駆動開発を続けること自体を目的にすると、Specが新しい負債になる。

元資料では、次のような問題を「型を破る」きっかけとして挙げている。

- コーディングから人間レビューへ移るところがボトルネックになる。
- 仕様ファイル同士、または仕様と実装のドリフト管理が重くなる。
- 自然言語の仕様では機械的に検査できない領域が増える。
- 詳細なSpecがAgentの能力を引き出すより、余分な制約として働く。

この段階では、不要なSpecを剥がし、ADRやコードそのものへ情報を移す選択肢が出てくる。

仕様駆動開発は永続的な完成形ではなく、チームが共通理解を作るための足場として評価した方がよい。

課題に突き当たるまでは、変更内容を人間が追いやすくし、チームの意識を合わせる型として機能する。

チーム全員がその型を重いと感じるようになったときが、次の方法へ移るタイミングになる。

## 関連

- [[Context Paradigm]]
- [[Software Engineering]]

## 参考資料

- 渡邉 洋平, 「仕様駆動開発の消費期限」
- [[仕様駆動開発の消費期限.pdf]]
- Kiro, `Kiro and the future of AI spec-driven software development`
- https://kiro.dev/blog/kiro-and-the-future-of-software-development/
- GitHub Blog, `Spec-driven development with AI: Get started with a new open source toolkit`
- https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/
- Martin Fowler, `Understanding Spec-Driven-Development: Kiro, spec-kit, and Tessl`
- https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html
- Thoughtworks Technology Radar, `Codebase cognitive debt`
- https://www.thoughtworks.com/radar/techniques/codebase-cognitive-debt
- `Comprehension Debt in GenAI-Assisted Software Engineering Projects`
- https://arxiv.org/abs/2604.13277
