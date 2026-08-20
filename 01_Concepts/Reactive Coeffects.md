# Reactive Coeffects（リアクティブな依存関係）

## 概要

コンポーネントが安全に動くためには、「自分が何を変更するか」だけでなく、「何が存在していれば自分が動けるか」も扱う必要がある。

*A Programming Paradigm for Spatiotemporal Composability* では、後者を **Coeffect** として捉える。

Effect が「この計算は環境へ何をするか」を表すのに対し、Coeffect は「この計算は環境から何を必要とするか」を表す。論文はこの古典的な概念を runtime の依存関係管理へ持ち上げ、**Reactive Coeffects** として構成する。

## 依存関係を宣言し、満たされたときだけ動かす

各コンポーネントは、自分が必要とする dependency key の集合を specification として宣言する。

たとえば Database と Logger が必要なら、両方が Context 上で提供されているときだけ、そのコンポーネントは active になれる。どちらかが欠ければ起動しない。

Context が変化するたびに、runtime は specification の充足状態を再評価する。

```text
未充足 → 充足    : activating
充足   → 未充足  : deactivating
それ以外         : neutral
```

この分類が lifecycle を駆動する。依存先が出現すれば起動し、消えれば停止する。単に「同じ key があるか」だけでなく、どの provider に解決されているかを committed view として保持するため、provider が別のものへ置き換わった場合も再構成の対象になる。

通常の Dependency Injection が起動時に一度 wiring して終わるのに対し、Reactive Coeffects は **runtime の dependency topology が変わるたびに再解決する DI** と考えると分かりやすい。

## 「依存先が消えたので止める」だけでは不十分

依存関係を動的に扱うと、停止順序が問題になる。

Database provider を停止したいとして、それに依存する consumer を先に止めればよさそうに見える。しかし consumer の teardown 自体が Database を必要とする場合がある。connection pool を閉じるために、connection を provider へ返す必要がある、といったケースである。

そのため論文では、provider の停止を二段階に分ける。

```text
Provider ACTIVE
      ↓ 停止開始
新規の依存先としては利用不可
      ↓
Dependents が deactivation
      ↓
Dependents の teardown 完了
      ↓
Provider の inverse を実行
      ↓
Provider INACTIVE
```

provider が `UNLOADING` に入った時点で新しい consumer からは見えなくする。しかし、すでにその provider に commit している consumer は、自身の teardown が終わるまで従来の binding を読み続けられる。

さらに provider 側の recovery は、依存していた consumer がすべて deactivation を終えるまで待つ。論文ではこれを withdrawal の guard として形式化している。

この構造によって Spatial Composability は、単なる dependency change notification ではなく、**依存関係に沿った lifecycle ordering の保証**になる。

## Coeffect Isolation

同じ dependency key でも、すべてのコンポーネントが同じ値を見るとは限らない。

テスト環境、マルチテナント、サンドボックスなどでは、同じ `database` key を使いながら、Context ごとに別の Database を解決したい。

Coeffect Isolation は、key と実際の binding の間に realm を挟む。

```text
key → realm → value
```

Context ごとに key が異なる realm を指せるため、同じ論理 key を別の値へ解決できる。これは runtime 上の ad-hoc polymorphism に近い。

重要なのは、shared table 自体を書き換えるのではなく、**その Context からどう解決するかを変える**点である。そのため isolation は、親 Context を壊さず子 Context を派生させる形で実現できる。

## Coeffect Interception

Isolation が「何に解決するか」を変えるのに対し、Interception は「どう使えるか」を変える。

たとえば filesystem dependency を提供するとき、component ごとに読み書き可能な path を制限したい場合がある。Database なら read-only 権限だけ渡したい場合もある。

Interception では、Context や component declaration に metadata を付与し、provider が dependency access のたびにその metadata を参照する。

これにより、provider のコードや consumer のコードを変更せず、外側の Context からアクセス方針を絞れる。

この仕組みは、論文の Access Control の議論では capability-based security に近いものとして扱われている。component の dependency declaration が capability request、Context が mediator の役割を持つ。

ただし、悪意あるコードが host runtime そのものへ直接アクセスできる場合、言語レベルの mediation だけでは十分ではない。その場合は process、Wasm、container など、別の sandbox 境界が必要になる。

## Reactive Coeffects が解くもの

Reactive Coeffects の価値は、「依存関係を宣言できる」こと自体ではない。

- 依存が揃うまで component を起動しない
- provider が消えれば consumer を停止する
- provider が置き換われば必要な consumer だけ再構成する
- teardown 中は committed dependency を保持する
- dependency の withdrawal を consumer の停止後まで遅延させる
- Context ごとに dependency resolution や access policy を変える

こうした lifecycle と dependency の関係を、runtime が同じ規則で管理できることにある。

これが [[Spatiotemporal Composability]] における空間方向の保証である。

## 関連

- [[Spatiotemporal Composability]]
- [[Revertible Effects]]
- [[Context Paradigm]]
- [[Dynamic Component Lifecycle]]
- [[Cordis]]

## 参考資料

- Yifan Shi, Wei Zhang, Tianyi Cui, *A Programming Paradigm for Spatiotemporal Composability*, Peking University / DeepSeek-AI.
- 原文PDF: `[[09_References/Spatiotemporal Composability/A Programming Paradigm for Spatiotemporal Composability.pdf]]`
