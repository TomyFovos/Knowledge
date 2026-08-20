# Cordis

## 概要

Cordis は、*A Programming Paradigm for Spatiotemporal Composability* で提案された [[Spatiotemporal Composability]] を実装する TypeScript 製の meta-framework である。

Web framework や ORM のように特定 domain の機能を提供するのではなく、**Component を runtime で安全に load / unload / reconfigure するための共通 semantics**を提供することを目的としている。

理論上の二本柱は、

- [[Revertible Effects]]
- [[Reactive Coeffects]]

であり、それらを [[Context Paradigm]] と [[Dynamic Component Lifecycle]] にまとめて実装する。

## Core library

Cordis では、Context に対する mutation を `ctx.effect` へ通す。

`ctx.effect` は callback を実行し、その callback が返す inverse を accumulator に積む。複数 Effect が実行されると inverse は LIFO に合成され、Context / Component を dispose したときにまとめて実行される。

```text
ctx.effect(callback)
```

これが Effect tracking の中心であり、dependency provision や child Component registration も最終的にはこの仕組みに乗る。

### Coeffect operations

Dependency 周りは、主に次の操作へ対応する。

```text
ctx.get(key)
ctx.set(key, value)
ctx.isolate(key, realm)
ctx.intercept(key, metadata)
```

`set` による provision 自体が Revertible Effect なので、provider を unload すると binding も自動的に撤回される。

`isolate` は同じ key を Context ごとに別 realm へ解決させる。

`intercept` は dependency の binding 自体ではなく、利用時の metadata を変え、access policy などを外側の Context から付与できる。

## Property access と dependency declaration

Cordis は reflective な `ctx.get(key)` に加えて、Context property として dependency を読む形も提供する。

TypeScript では Proxy を利用し、property access を mediation する。

その際、現在の fiber がその dependency を宣言しているか、committed view に binding が存在するかを確認する。未宣言 dependency への access や、まだ active でない dependency への access は reject される。

これにより Component の dependency declaration は documentation だけでなく、**runtime access control の一部**になる。

## `ctx.use` と Component instantiation

Component の instantiation は `ctx.use` で行われる。

新しい fiber は parent Context から child Context を派生し、その Component の dependency specification と Effect function を保持する。

Child registration 自体が parent の tracked Effect になるため、parent が unload されれば、その inverse として child の retirement が走る。

この仕組みによって、Component tree と recovery tree が対応する。

## Lifecycle engine

Cordis の fiber は概ね、

```text
INACTIVE
LOADING
ACTIVE
UNLOADING
FAILED
```

の状態を持つ。

Runtime は dependency resolution から `fiber.target` を再計算し、現在の committed view と比較する。

- dependency が揃えば reload
- dependency が消えれば unload
- provider が置換されれば reload
- transition 中に target が変われば rollback / chaining

という処理を行う。

Provider が unload に入ると、まず新規 dependency resolution から外す。その後、影響を受けた dependents に通知し、dependents の teardown 完了を待ってから provider 自身の disposer を実行する。

これは [[Reactive Coeffects]] の withdrawal ordering を実装した部分である。

## Declarative Component Loader

Core library の上には、desired composition を data として記述する Component Loader がある。

各 entry は概ね、

- stable id
- component module URL
- isolation
- interception
- config
- disabled flag

を持つ。

Loader はこの configuration tree を authoritative record とし、変更があれば既存 fiber と差分を reconcile する。

重要なのは、configuration 全体を毎回 teardown / rebuild しないことである。

- component identity が変われば rebuild
- isolation が変われば realm を再割当
- interception は read-time metadata なので in-place 更新
- config は component 側に差分処理を委ねる
- disabled は unload / reload

というように、変更内容ごとに最小限の操作へ落とす。

この設計は、最終状態への収束性を lifecycle 側の性質へ委ねる。Orchestrator が厳密な activation 順を手で組むのではなく、dependency satisfaction が activation timing を決める。

## Hot Module Replacement

Cordis の HMR は、Component lifecycle の上に構築されている。

変更 module の dependency graph を分類し、影響する entry を特定したうえで stale fiber を dispose し、新 module から fiber を作り直す。

Import に失敗した場合は module cache と fiber を backup から戻すため、half-reloaded state を残さない。

詳しくは [[Transactional Hot Module Replacement]]。

## Koishi での実運用

論文は Cordis の case study として Koishi を扱う。

Koishi は chatbot application framework で、server-side の機能を Cordis plugin として構成している。さらに browser 上の web console も独立した Cordis application として動く。

論文執筆時点で Koishi には **4000を超える community plugin** が存在し、IM adapter、database driver、管理 UI、end-user feature など多様な Component が同じ composition model 上で動いている。

実運用では、

- console から plugin を disable して process restart なしで Effect を撤回
- development 中に HMR で plugin を再適用
- cache や live connection など他 Component の state を残したまま対象 plugin だけ交換
- provider が再構成されたとき、影響する dependent だけ lifecycle を再評価

といった動作が行われる。

この case study が示すのは、形式モデルが単なる toy calculus ではなく、大規模 plugin ecosystem を支えられる程度の expressiveness を持つという **existence / adoption の証拠**である。

ただし論文自身も限界を明記している。評価対象は一つの ecosystem と一つの host language であり、alternative architecture との controlled comparison ではない。Runtime overhead や developer productivity の定量比較も今後の課題である。

## Self-Evolving Agent Harness との関係

論文は Cordis の次の検証対象として、self-evolving agent harness を明示している。

Agent が tool、memory、sandbox、subagent orchestration など harness 自体の Component を継続的に生成・差し替える場合、full restart では process-local state や in-flight task が失われる。また dependency topology も頻繁に変わる。

Cordis のモデルは、この問題に対して、

- Component replacement 時の完全回復
- dependency topology 変化への lifecycle coordination

を与えられる可能性がある。

ただしこれは論文中では **将来の検証対象**であり、Koishi と同程度に実証済みという意味ではない。

## 関連

- [[Spatiotemporal Composability]]
- [[Revertible Effects]]
- [[Reactive Coeffects]]
- [[Context Paradigm]]
- [[Dynamic Component Lifecycle]]
- [[Transactional Hot Module Replacement]]
- [[System Boundary and Recoverability]]

## 参考資料

- Yifan Shi, Wei Zhang, Tianyi Cui, *A Programming Paradigm for Spatiotemporal Composability*, Peking University / DeepSeek-AI.
- 原文PDF: `[[09_References/Spatiotemporal Composability/A Programming Paradigm for Spatiotemporal Composability.pdf]]`
