# Transactional Hot Module Replacement

## 概要

Hot Module Replacement（HMR）は、process を再起動せずに変更された module を差し替える仕組みである。ただし一般的な HMR は「新しい module を読み込めるか」だけでなく、古い module が残した副作用や dependency をどう片付けるかという問題を抱える。

*A Programming Paradigm for Spatiotemporal Composability* では、[[Cordis]] の HMR を [[Revertible Effects]] と [[Dynamic Component Lifecycle]] の応用として構成する。

Component のすべての Effect が fiber に束縛されているなら、module replacement は概念的に、

```text
old fiber を dispose
→ module cache を更新
→ new module から new fiber を instantiate
```

するだけでよい。

古い fiber の teardown path を HMR 専用に書く必要はなく、通常の component unload がそのまま module replacement に使える。

## なぜ acceptance boundary を手書きしなくてよいのか

Webpack や Vite の HMR では、どこまでの module が hot replace を受け入れられるかを application 側が明示することがある。

Cordis では Component 自体が Effect / Coeffect の境界を持つため、Component を replacement boundary として利用できる。

古い Component の Effect は fiber accumulator に記録されている。したがって replacement 時には、その fiber を通常どおり unload すればよい。新しい code は新しい fiber として load される。

この設計では、HMR が独立した特殊機構ではなく、**Component lifecycle の一操作**になる。

## 3段階の HMR

論文の Cordis loader は、HMR を三段階で処理する。

### 1. Module classification

まず、変更された module 群と、hot replace できず full restart が必要な external module 群から、dependency graph 上の module を accepted / declined に分類する。

変更された module の import graph を辿り、accepted な module へ依存するものを accepted 側へ伝播させる。一方、すべての import が declined なら declined にする。

Import cycle などで fixed point に達しても判定できない module は、安全側に倒して declined とする。

### 2. Stale-entry detection

次に、Component entry ごとの transitive dependency tree を調べ、accepted module と交差する entry を stale と判定する。

この段階では、「変更された file」そのものではなく、**その file の変更によって再 instantiate すべき Component はどれか**を特定する。

### 3. Transactional reload

最後に stale entry を reload する。

1. accepted module の cache を invalidate し、古い cache を backup
2. stale fiber を dispose
3. 新しい module を import
4. 新しい fiber を instantiate

という順で進む。

途中で syntax error などにより import が失敗した場合、cache を backup から戻し、stale entry も以前の component から作り直す。

つまり HMR 自体を transaction として扱い、**半分だけ新しい code に置き換わった状態を残さない**。

## State をどう扱うか

Cordis の HMR は、Dynamic Software Updating のように component 内部の任意 state を新 version へ migrate する方式ではない。

基本的には古い Component の tracked Effects を撤回し、新しい Component を clean slate から適用し直す。そのため、Component 内部だけに保持していた in-memory state は reload で失われる。

State を保持したいなら、より長寿命な dependency 側へ置く必要がある。

これは制約だが、代わりに HMR ごとの hand-written migration function を要求しない。論文は、DSU-style forward migration と Revertible Effects の組み合わせを将来課題としている。

## HMR を一般化すると何が見えるか

このパターンのポイントは HMR の実装技術そのものではない。

Component が、

- 自分が残した Effect を回収できる
- Dependency が runtime で再解決される
- Failure 時に rollback できる

という性質を持っていれば、code replacement は特別な operation ではなくなる。

つまり、**replace を安全にするのではなく、普段から unload / reload が安全な Component model を作ることで replace も安全にする**という発想である。

これは self-updating system や agent harness の component replacement を考えるときにも応用可能な設計原則だが、論文内で実証されているのは Cordis / Koishi の plugin ecosystem までであり、self-evolving agent harness への適用は将来検証として位置づけられている。

## 関連

- [[Spatiotemporal Composability]]
- [[Revertible Effects]]
- [[Dynamic Component Lifecycle]]
- [[Cordis]]

## 参考資料

- Yifan Shi, Wei Zhang, Tianyi Cui, *A Programming Paradigm for Spatiotemporal Composability*, Peking University / DeepSeek-AI.
- 原文PDF: `[[09_References/Spatiotemporal Composability/A Programming Paradigm for Spatiotemporal Composability.pdf]]`
