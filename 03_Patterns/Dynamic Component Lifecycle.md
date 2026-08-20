# Dynamic Component Lifecycle

## 概要

[[Revertible Effects]] と [[Reactive Coeffects]] が個々の操作を扱うのに対し、実際のシステムでは、それらを **Component の lifecycle** にまとめる必要がある。

*A Programming Paradigm for Spatiotemporal Composability* では、Component を概念的に次の三つ組として扱う。

```text
Component = (dependencies, provisions, effects)
```

- `dependencies`：環境から必要とする Coeffect
- `provisions`：自分が環境へ提供できる Coeffect
- `effects`：active になったときに実行する Revertible Effects

これを実行中の system に instantiate したものを **fiber** と呼ぶ。fiber は Component 定義だけでなく、現在の lifecycle state、dependency の committed view、Effect の accumulator、親 fiber などを持つ。

## target と committed view

Lifecycle を動かす中心は、現在の dependency resolution と、Component が起動時に commit した resolution の比較である。

`target` は「今この fiber がどうあるべきか」を表す。

- dependency が満たされていない、または retire 済みなら `INACTIVE`
- dependency が揃っていれば、その provider の集合が target

一方 `committed view` は、その fiber が activation を開始したときに依存していた provider の集合である。

この二つが一致していればそのまま動ける。違えば、provider の消失・置換などが起きているため unload / reload が必要になる。

値そのものではなく **provider identity** を記録することが重要である。新旧 provider が同じ値を返していても、provider が置き換わったことを検出できるからである。

## 単純な Active / Inactive では足りない

現実の Component は、一瞬で load / unload できるわけではない。

初期化の途中で `await` することもあり、複数 Effect を順に適用することもある。teardown の途中で dependent の終了を待つこともある。さらに途中で失敗する可能性もある。

そのため論文は lifecycle を概ね次の状態へ拡張する。

```text
INACTIVE
   ↓
RELOADING
   ↓
ACTIVE
   ↓
UNLOADING
   ↓
INACTIVE
```

`RELOADING` 中に dependency target が変われば、その時点までの Effects を回収して `UNLOADING` に移る。すでに非同期 iteration が走っている場合は、その iteration 自体は着地させ、その後で rollback する。

この「開始した transition は着地させてから次へ進む」性質を論文は inertia として扱う。

## Provider の停止には guard が必要

Spatial Composability の難所は、provider と consumer の停止順序である。

provider が停止を開始すると、新規 consumer からは利用できない状態にする。しかし既存 consumer は teardown の間、commit 済みの provider を使い続けられる必要がある。

そこで provider の physical withdrawal、つまり inverse の実行は、**その provider に依存している installed consumer がいなくなるまで待つ**。

この guard によって、

```text
provider が停止を表明
→ consumer が先に deactivation
→ consumer teardown 完了
→ provider の Effect を回収
```

という ordering が成立する。

単に dependency graph を見て「逆順に stop する」という静的処理ではない。runtime の committed view を使って、**実際にどの provider に commit していた consumer が残っているか**を見て待つ。

## Orchestrator は lifecycle state を直接変更しない

論文の calculus では、Orchestrator が行う操作と、Lifecycle runtime が行う操作を分けている。

Orchestrator が直接できるのは、Component の insertion や retirement などの「望ましい構成を変えること」である。`ACTIVE` を直接セットするわけではない。

その後、runtime が target を比較し、必要な lifecycle transition を進める。

この分離は declarative orchestration と相性がよい。Orchestrator は「最終的に何が存在してほしいか」を指定し、runtime が dependency と recovery の規則に従ってそこへ収束させる。

## 論文が示す4つの全体保証

この lifecycle calculus について、論文は局所的な仕組みを system 全体の性質へ持ち上げる。

### Preservation

Lifecycle transition を進めても、registry の構造や dependency resolution の整合性が壊れない。

### Temporal Composability

複数 fiber の Effects が interleave しても、必要な independence 条件を満たしていれば、一つの fiber の accumulator は **その fiber の寄与だけ**を取り除く。

### Spatial Composability

Consumer は dependency が提供されている状態でだけ起動し、provider の withdrawal は dependent の deactivation 後まで遅延される。また transition の途中で dependency resolution が変化した場合、そのまま stale な前提で active にならず rollback 側へ進む。

### Progress / Confluence

Dependency relation が acyclic で、Component 数や iteration 数などに一定の有限性がある場合、system は deadlock せず quiescent state へ進む。

さらに failure がなく、independence や provision の条件を満たす場合、最終的な quiescent state は lifecycle の実行順に依存せず、**最終構成を最初から dependency 順に静的に組み上げた状態と同等**になる。

この Confluence は、動的な system を理解するうえで強い性質である。

「途中で何回 reload したか」ではなく、「最終的にどの Component が存在するか」を見て final state を reasoning できるからである。

## ただし無条件ではない

この保証は、任意の Component code に対して自動的に成立するものではない。

論文では少なくとも、

- Component 間の Effects が必要な independence を満たすこと
- dependency relation が acyclic であること
- Component の provision declaration と実際の provision が整合すること
- recovery inverse が正しいこと
- Confluence では failure が除外されること

などを前提にしている。

したがって lifecycle engine の存在だけで安全になるのではなく、**Component が runtime の composability discipline に従っていること**が重要になる。

## 関連

- [[Spatiotemporal Composability]]
- [[Revertible Effects]]
- [[Reactive Coeffects]]
- [[Context Paradigm]]
- [[Cordis]]
- [[Transactional Hot Module Replacement]]

## 参考資料

- Yifan Shi, Wei Zhang, Tianyi Cui, *A Programming Paradigm for Spatiotemporal Composability*, Peking University / DeepSeek-AI.
- 原文PDF: `[[09_References/Spatiotemporal Composability/A Programming Paradigm for Spatiotemporal Composability.pdf]]`
