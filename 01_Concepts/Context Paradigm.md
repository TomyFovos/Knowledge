# Context Paradigm

## 概要

[[Revertible Effects]] と [[Reactive Coeffects]] は、それぞれ「環境へ何をするか」と「環境から何を必要とするか」を扱う。

*A Programming Paradigm for Spatiotemporal Composability* がさらに踏み込むのは、この二つを別々の機構として置かず、**一つの Context を介して統合する**点である。

論文は、この統合された Context を単なる framework API ではなく、一つの programming paradigm として位置づけている。

## Context にすべての相互作用を通す

概念的な Context は次のような再帰構造を持つ。

```text
Γ∞ = μΓ. Γ × (Γ → Γ) × Σ
```

ここには、

- 現在の Context state
- そこまでの Effect を戻す accumulator
- dependency 情報を持つ Coeffect Context `Σ`

が同居する。

その結果、Component が外界に対して行う操作を Context に集約できる。

Component が dependency を提供する操作も Context の変更なので Effect として追跡される。Component を unload すれば、その dependency provision も inverse によって撤回される。Consumer は Context を介して dependency を取得し、その binding の変化が lifecycle に反映される。

つまり、

```text
何を変えたか  → Effect
何を必要とするか → Coeffect
誰の操作か    → Context
```

という三つを同じ境界で結びつける。

## Functional と imperative の中間に置く

論文は Context Paradigm を、二つの既存スタイルの間に位置づける。

純粋関数型の explicit state threading では、状態が明示的に受け渡されるため追跡しやすい一方、あらゆる call chain が state parameter を運ぶ必要があり、記述量が増える。

逆に imperative / OOP では、共有状態や service locator に暗黙にアクセスできるため書きやすい。しかし、ある関数が何を変更し何に依存しているのかを知るには、実装を推移的に追わなければならない。

Context Paradigm は、その中間を狙う。

Effect と Coeffect を Context への操作として明示することで attribution を保ちながら、Component 作者は各 operation を普通の imperative operation に近い形で扱える。

論文の主張は、**Functional の traceability と imperative の ergonomics を両立し、そのうえで lifecycle 単位の自動合成を得る**というものである。

## 階層的な Context

Context は一枚の global table ではない。

親 Context から子 Context を派生でき、子 Component の Effect は親側の accumulator に統合される。Component が別の Component を起動した場合も、その登録自体を親の Effect として扱える。

この階層構造によって、

- 親を unload すると子も retire する
- 子の Effect は子の lifecycle に閉じる
- Isolation / Interception を子 Context にだけ適用できる

という制御が可能になる。

ここでは「plugin」という比喩がかなり文字通りになる。

```text
load   = Context に Effects を差し込む
unload = その Effects を回収する
dependency = Context 上で解決する
child component = 派生 Context へ差し込む
```

## Observational Equivalence — 何をもって「元に戻った」とするか

Revertible Effects が Context を回復するといっても、現実の物理状態を完全に同一に戻せるとは限らない。

`malloc` のあとに `free` しても、heap の内部配置まで以前と同じになるとは限らない。生成した ID を捨てても、次回同じ ID が生成される必要はない。

そこで論文は equality ではなく **observational equivalence（観測同値）**を用いる。

二つの状態が、Context を通して利用可能な operations から区別できないなら、内部表現が違っていても同じ状態として扱う。

これは「回復」という言葉の範囲を決める重要な考え方である。

Spatiotemporal Composability が要求するのは物理世界の巻き戻しではなく、**Component が観測できる意味の回復**である。

## Context に通らない操作は保証外になる

Context Paradigm の保証は、Component と環境の相互作用が Context によって mediation されることを前提にしている。

Component が global variable や host runtime の object を直接掴み、Context を迂回して書き換えた場合、その操作は Effect tracker から見えない。宣言していない dependency を直接取得すれば、Coeffect specification からも外れる。

したがって Context は convenience API ではなく、**保証を成立させる system boundary**である。

この点は sandbox とも関係する。信頼できない code に対し「Context だけを使ってください」と規約で要求するだけでは足りない。host object へ直接到達できるなら mediation を迂回できるため、必要に応じて process、Wasm、container などの sandbox が要る。

## Context Paradigm の設計上の意味

この考え方から得られる設計上のメッセージは、Context Object を導入することそのものではない。

重要なのは、

- state mutation
- resource acquisition
- dependency provision
- dependency access
- child component registration

といった「Component と外界の境界を越える操作」を、**誰の lifecycle に属する操作なのかが分かる形で一つの mediation layer に通す**ことである。

そこまでできて初めて、Effect の回収と Coeffect の再解決を同じ Component lifecycle に結びつけられる。

## 関連

- [[Spatiotemporal Composability]]
- [[Revertible Effects]]
- [[Reactive Coeffects]]
- [[Dynamic Component Lifecycle]]
- [[System Boundary and Recoverability]]
- [[Cordis]]

## 参考資料

- Yifan Shi, Wei Zhang, Tianyi Cui, *A Programming Paradigm for Spatiotemporal Composability*, Peking University / DeepSeek-AI.
- 原文PDF: `[[09_References/Spatiotemporal Composability/A Programming Paradigm for Spatiotemporal Composability.pdf]]`
