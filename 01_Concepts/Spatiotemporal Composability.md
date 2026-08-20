# Spatiotemporal Composability（時空間合成可能性）

## 概要

実行中のシステムから、一つの機能だけを安全に抜き取ることはできるだろうか。

単にコードを差し替えるだけなら、Hot Module Replacement やプラグイン機構でもできる。しかし、その機能が登録したイベント、確保したリソース、書き換えた共有状態まで元に戻し、さらにその機能に依存していた別の機能だけを正しい順序で停止・再起動させるとなると、問題は急に難しくなる。

**Spatiotemporal Composability（時空間合成可能性）**は、この「実行中にコンポーネントを追加・削除・再構成しても、システム全体を壊さない」ための合成可能性を、二つの軸に分けて捉える考え方である。

- **Temporal Composability（時間的合成可能性）**：コンポーネントを取り外したとき、そのコンポーネントが環境に残した副作用を安全に撤回できること
- **Spatial Composability（空間的合成可能性）**：コンポーネント間の依存関係を宣言でき、その依存先の追加・削除・置換に応じてライフサイクルを再調整できること

論文 *A Programming Paradigm for Spatiotemporal Composability* は、この二つを古典的な **Effect / Coeffect** の考え方から組み立て直し、コンパイル時の型解析ではなく、**実行時に作用する仕組み**へ持ち上げている。

この発想の重要な点は、「プラグインを消せるようにする」「依存性注入を動的にする」といった個別テクニックではない。**コンポーネントが環境に対して「何を変えるか」と「何を必要とするか」を、同じ Context を介して管理する**ことで、動的なシステムそのものに一貫した合成規則を与えようとしている。

## なぜ再起動では足りないのか

現在のソフトウェアでも、動的な再構成そのものは珍しくない。IDE の拡張機能、サーバーのプラグイン、依存性注入、コンテナオーケストレーションなど、構成を後から変える仕組みはすでに多数存在する。

それでも、多くの仕組みは「細粒度のコンポーネントを安全に取り外す」問題を、より粗い境界へ逃がしている。

たとえば一つのプラグインに問題が起きたとき、そのプラグインだけを完全に取り除くのではなく、プロセス全体を再起動する。サービス間依存については、アプリケーション内部ではなく Kubernetes のようなコンテナ境界で管理する。

これは実用的ではあるが、粒度が合っていない。

プロセスを再起動すれば、そのプロセスに蓄積されていたキャッシュ、コネクション、途中の計算、セッションに近い状態までまとめて失われる。可用性を守るためには複製を用意しなければならない。逆に、同一プロセス内のコンポーネント同士の依存関係は、コンテナオーケストレーターからは見えない。

問題は、**変更したい単位はコンポーネントなのに、回復や依存関係管理の単位がプロセスやサービスになっている**ことにある。

この粒度のずれは、[[Software Engineering]] の一般論として見れば「複雑なシステムを部品へ分解したのに、その部品境界で安全性を保証できていない」状態とも言える。

## 二つの合成可能性

### Temporal Composability — 自分が残した痕跡を消せるか

コンポーネントをロードすると、単にコードがメモリへ載るだけではない。

イベントリスナーを登録する。ルートを追加する。タイマーを開始する。共有テーブルを書き換える。別のコンポーネントを起動する。こうした処理はすべて、システムの Context を変更する **Effect** と考えられる。

時間的合成可能性が要求するのは、アンロード時にこれらを「だいたい元に戻す」ことではない。コンポーネントが行った変更を追跡し、そのコンポーネントの寄与だけを撤回できることである。

論文では、Effect を概念的に次の形で扱う。

```text
e : Γ → Γ × (Γ → Γ)
```

Effect を現在の Context `Γ` に適用すると、変更後の Context と同時に、**その変更を戻す inverse（逆操作）**を返す。

重要なのは cleanup を別の場所に書くのではなく、**変更を行う瞬間に、その変更を戻す方法も対にする**点にある。

複数の Effect が実行されると、それぞれの inverse は蓄積される。アンロード時には最後に実行した Effect から逆順に戻す。いわゆる LIFO である。

これによって、コンポーネント作者は「このプラグイン全体をどうアンインストールするか」を手書きする必要がなくなる。必要なのは、個々の原子的な操作について inverse を与えることであり、**複合的な teardown は runtime が合成する**。

ただし、ここには大事な条件がある。複数コンポーネントの Effect が同じ状態を好き勝手に書き換える場合、一方だけを後から戻すと他方の変更まで壊す可能性がある。

そのため論文は、Effect 同士の **independence / commutativity（独立性・可換性）**を扱う。異なるコンポーネントの操作が独立なら、実行順序が入り交じっていても、一方の inverse だけを適用して、そのコンポーネントの寄与だけを撤回できる。

つまり時間的合成可能性は、単なる Undo Stack ではない。

> **「誰の変更なのか」を追跡し、他者の変更と混ざった後でも、その一人分だけを撤回できること**

が本質になる。

### Spatial Composability — 依存先が変わったときに追従できるか

もう一方の Spatial Composability は、コンポーネントの「外部への要求」を扱う。

あるコンポーネントが Database を必要とするなら、Database が存在するときだけ動けばよい。Database の provider が消えたなら、そのコンポーネントも停止する必要がある。別の provider に差し替わったなら、新しい依存先を前提として再起動する必要がある。

これは **Coeffect** の問題として扱われる。

Effect が「この計算は環境に何をするか」を表すのに対し、Coeffect は「この計算は環境から何を必要とするか」を表す。

各コンポーネントは必要な dependency key の集合を specification として宣言する。Context が変化するたびに、その specification が満たされているかを再評価し、変化を三種類に分類する。

```text
未充足 → 充足    : activating
充足   → 未充足  : deactivating
それ以外         : neutral
```

依存関係が揃えばコンポーネントを起動し、失われれば停止する。依存先そのものが置き換わった場合も、現在の binding と新しい binding が異なるため再構成の対象になる。

通常の Dependency Injection と違うのは、依存関係を起動時に一度解決して終わるのではなく、**runtime の topology が変わるたびに再解決する**ことである。

## 「依存先が消えたから止める」だけでは足りない

ここで厄介な問題が出る。

Database provider を停止するとき、依存する consumer を先に停止させればよい。しかし consumer の teardown 処理そのものが Database を必要としているかもしれない。

たとえば connection pool を閉じるには、保有している connection を provider 側へ返す必要がある。

そのため Cordis のモデルでは、provider が停止を開始した瞬間に「新規依存先としては利用不可」にする一方で、すでにその provider に commit している consumer からは teardown が完了するまで読み続けられるようにする。そして provider の inverse は、依存していた consumer がすべて停止してから実行する。

この順序は概念的には次のようになる。

```text
Provider ACTIVE
      ↓ 停止要求
Provider は新規利用不可になる
      ↓
Dependents が deactivation を開始
      ↓
Dependents の teardown 完了
      ↓
Provider の inverse を実行
      ↓
Provider INACTIVE
```

この **withdrawal guard** があることで、「依存が消えたことを通知する」と「依存そのものを物理的に撤回する」を分離できる。

Spatial Composability は単なるイベント通知ではなく、**依存関係に沿ったライフサイクル順序の保証**なのである。

## Effect と Coeffect を一つの Context に統合する

論文が「プログラミングパラダイム」と呼ぶ中心はここにある。

Effect 用 Context と Coeffect 用 Context を別々に置くのではなく、再帰的な一つの Context として統合する。

概念的には次の形になる。

```text
Γ∞ = μΓ. Γ × (Γ → Γ) × Σ
```

Context は、

- 現在の状態
- そこまでに行われた Effect を戻す accumulator
- dependency 情報を持つ Coeffect Context `Σ`

を同時に保持する。

その結果、**コンポーネントと外界の相互作用をすべて Context 経由へ集約できる**。

Effect は Context を変更し、その inverse が記録される。Dependency の提供自体も Context を変更する Effect なので、provider をアンロードすれば dependency の登録も自動的に撤回される。Consumer は Context から依存先を取得し、その binding の変化が lifecycle へ反映される。

この構造には階層性もある。Context から子 Context を派生させ、子の Effect を親へまとめることで、コンポーネントを入れ子にできる。

「plug-in」という言葉が、ここではかなり文字どおりになる。

- load = Context に Effect を差し込む
- unload = その Effect を回収する
- dependency = Context 上で解決される
- nested component = 子 Context として差し込む

### 完全に同じ状態へ戻す必要はない

現実には、物理状態をビット単位で元に戻せないことも多い。

`malloc` の後に `free` しても、ヒープの内部配置まで以前と完全に同一になるとは限らない。生成した ID を捨てても、次に生成される ID が以前と同じになる必要はない。

そこで論文は、回復を単純な equality ではなく **observational equivalence（観測同値）**として捉える。

外から利用できる操作を通して区別できないなら、内部表現が違っていても「元に戻った」と扱う。

これは重要な緩和である。時空間合成可能性が要求しているのは、物理世界を完全に巻き戻すことではなく、**システムの公開された Context から観測可能な意味を回復すること**だからである。

## Component は「要求・提供・作用」の三つ組になる

このパラダイムでは、Component を単なるコード塊とは考えない。

概念的には、

```text
Component = (dependencies, provisions, effects)
          = (d, p, e)
```

として扱う。

- `d`：環境から必要とするもの
- `p`：環境へ提供するもの
- `e`：active な間に Context へ与える Effect と、その inverse

この定義が面白いのは、**インターフェースとライフサイクルが分離されていない**ことである。

何を必要とし、何を提供し、その状態を作るために何を行ったかが、一つの component の境界に閉じる。

実行時には Component のインスタンスを **Fiber** として扱い、それぞれが独立した lifecycle state、accumulator、依存先の committed view を持つ。

ライフサイクルは単純な Active / Inactive だけではなく、現実の非同期処理や途中失敗を扱うために次の状態を持つ。

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

RELOADING 中に依存関係が変われば、途中まで行った Effect を回収して UNLOADING へ向かう。非同期処理がすでに飛んでいる場合は、その処理を途中で消したことにはせず、一度着地させてから rollback する。Effect の途中で失敗した場合も、それまでに積んだ inverse を実行してから failed state に入る。

「動的に差し替えられる」という言葉の裏には、これだけの lifecycle semantics が必要になる。

## システム全体では何が保証されるのか

論文の形式化が長い理由は、個々の Component で Undo と依存解決ができるだけでは、システム全体の正しさにならないからである。

複数 Component が同時に動き、Effect が interleave し、dependency graph が変わり続ける状況でも性質が保たれることを示す必要がある。

論文は、一定の仮定の下で主に次の性質を与えている。

### Recovery exactness

ある Fiber の activation 中に他の Fiber が何度状態を変更しても、Effect が pairwise independent なら、その Fiber の accumulator を実行することで**その Fiber 自身の寄与だけを取り除ける**。

### Dependency ordering / resolution coherence

Consumer は Provider が active になった後にだけ起動し、Provider は Consumer の deactivation が終わるまで撤回されない。

また、一つの activation が複数ステップにまたがっても、その途中で依存先が変わったなら transition を継続せず、旧 resolution で作りかけた状態を撤回する。

### Progress

dependency precedence graph が acyclic で、各 activation が有限ステップで終わり、Fiber 数も有限なら、guard が原因で永遠に止まることはなく、最終的に quiescent state へ到達する。

### Confluence

最も強い直感を与えるのが confluence である。

pairwise independence、acyclic dependency、provision の totality、failure がないことなどの条件を満たす場合、途中で Component を追加・削除・差し替え・再読み込みしても、最終的に落ち着く状態は、**最終構成だけを最初から dependency order で静的に組み立てた場合と同値**になる。

つまり動的な履歴が、最終状態へ不要な痕跡を残さない。

これは「いつ何を reload したか」を全部追わないと現在の状態を理解できないシステムから、**最終 configuration を見れば現在あるべき状態を推論できるシステム**への転換である。

ただし、この定理は無条件ではない。特に failure は confluence の対象から外されており、失敗するかどうかが interleaving に依存する場合、Fiber の lifecycle state は異なり得る。一方で、失敗した Fiber が途中まで残した Context 上の寄与は recovery によって消える、というところまでは維持される。

## Cordis — 理論を runtime へ落とす

論文は理論だけで終わらず、**Cordis** という TypeScript の meta-framework で実装している。

Cordis 自体は Web Framework や ORM のように特定ドメインを提供しない。「Component を動的に合成する意味論」だけを提供し、その上にアプリケーション framework を構築する。

### `ctx.effect` — Context を変更する唯一の入口

Cordis では Context に対する mutation を `ctx.effect` へ集約する。

Effect callback は変更を行い、その変更を戻す closure を返す。iterator として複数段階の Effect を yield することもでき、runtime は返された inverse を LIFO で畳み込む。

そのため、`ctx.effect` を通して行われた変更は Component の unload 時に自動回収できる。

ただし、ここは保証の境界でもある。

**Cordis runtime は「渡された inverse が本当に元へ戻すか」を検証しない。**

inverse の正しさは Component 作者の義務であり、形式理論はその witness が正しいことを前提としている。

### `ctx.set` / `ctx.get` — Dependency の提供と利用

Dependency の provision も Effect である。

`ctx.set(key, value)` が binding を Context へ登録し、返された inverse がその binding を削除する。追加時・削除時の双方で dependent へ notification が飛び、必要なら reload / unload が起きる。

### Isolation と Interception

同じ logical key でも、Context ごとに違う provider を見せたい場合がある。テスト環境、multi-tenant、sandbox などが典型である。

`ctx.isolate` は key を別 realm へ解決させることで、同じ key を異なる binding へ向ける。

`ctx.intercept` は binding 自体を変えるのではなく、「その dependency をどう使わせるか」に metadata を差し込む。たとえば filesystem capability に read-only や許可 path を与える、といった制御へ利用できる。

### `ctx.use` と Fiber lifecycle

Component の instantiation は `ctx.use` で行われ、Fiber が作られる。

親 Component が子 Component を起動すること自体も tracked Effect なので、親を unload すると子も retirement へ向かう。Component tree と Effect tree が同じ lifecycle discipline に乗る。

### Declarative Loader

Core API は imperative だが、application orchestration では desired state を宣言的に持ったほうが扱いやすい。

Cordis の loader は、component URL、config、disabled、isolation、interception などを持つ entry tree を authoritative configuration とし、その差分を Fiber operations へ変換する。

ここで confluence が効いてくる。途中の reconciliation order にかかわらず、条件が満たされる限り最終 configuration と同等の quiescent state へ収束するため、loader は必要最小限の変更だけを適用できる。

### Transactional HMR

Hot Module Replacement でも Component boundary が利用される。

変更された module の影響範囲を解析し、対象 Fiber を dispose、module cache を無効化して新しい Component を読み込む。import に失敗した場合は cache を backup から戻し、すでに差し替えた Fiber も旧 Component で再構築する。

そのため HMR が途中まで成功して「半分だけ新バージョン」という状態を残さないようにしている。

## Koishi — 4000以上のプラグインでの実例

Cordis の実運用例として、チャットボット framework **Koishi** が挙げられている。

Koishi には 4000 を超える community plugin があり、IM adapter、database driver、管理 UI、エンドユーザー機能などが独立に開発されている。

この事例で確認されているのは二つである。

一つは時間方向で、plugin を停止すると Context 経由で登録された Effect がその場で撤回され、開発時の HMR でも他 Component の cache や live connection を保ったまま対象 plugin だけを再適用できること。

もう一つは空間方向で、database や adapter といった provider を runtime で入れ替えたとき、その provider に依存する plugin だけが再調整され、dependency が存在しない plugin はエラーを出し続けるのではなく inactive のまま待てること。

ただし、このケーススタディは **Cordis が使えることの存在証明・採用実績**に近い。単一 ecosystem・単一 host language の観察であり、別 architecture と比較した controlled experiment ではない。runtime overhead や developer productivity がどれだけ改善するかは、論文自身が future work としている。

## 保証が届かない場所

時空間合成可能性は強力だが、「あらゆる副作用を巻き戻せる」という話ではない。

### 外界へ出てしまった emission

ファイルを open して descriptor を得ることは tracked acquisition にできる。descriptor を close すれば戻せる。

しかし、一度外部ファイルへ bytes を書いた、network へ packet を送った、決済を実行した、といった **外界への emission** は単純な inverse では元に戻せない。

この境界の外では、

- commit が確定するまで出力を保留する
- 返金や削除のような compensation を用意する

といった別の仕組みが必要になる。

したがって confluence が保証するのは **管理対象 Context の状態**であり、実行途中に世界へ放出したすべての出来事ではない。

### 悪意あるコードの Sandbox

Dependency declaration は capability-based access control に近い。宣言していない Dependency への proxy access を拒否し、interception で path 単位の権限制御を追加できる。

しかし、Component が host runtime 自体へ直接触れられるなら、この制約は迂回できる。

そのため untrusted Component には、process、container、WebAssembly、software fault isolation など、**言語レベルより外側の Sandbox が必要**と論文は明記している。

### Dependency cycle

`A → B → A` のように互いの提供物が揃うまで起動できない Component は、どちらも永遠に inactive になる。

論文はこの問題を component granularity の問題として捉え、双方向の関係を core component と integration component へ細分化することで DAG に変える方法を示す。ただし、細かくしすぎると設定・命名・理解コストが増える。

### Dependency の型とバージョン

形式モデルでは key identity が一致すれば dependency が成立する。しかし独立開発された ecosystem では、同じ key の interface が version 間で変わったり、無関係な package が同じ key 名を使ったりする。

Cordis は現状 peer dependency による version compatibility を利用しているが、semantic versioning への依存など限界もある。package namespace、peer dependency、structural compatibility をどう統合するかは open problem とされている。

## Self-Evolving Agent Harness への含意

この論文が特に興味深いのは、motivating example と将来の検証対象として **self-evolving agent harness** を明示していることである。

エージェントハーネスは、tool、execution environment、permission / sandbox、session state、memory、subagent、multi-agent orchestration などを runtime に組み合わせる。

さらにハーネス自身が、自分の Component を生成・交換するようになれば、その一回一回が dynamic composition になる。

このとき「新しいコードを生成できる」だけでは足りない。

新しい tool を入れた結果、古い tool が登録した hook が残ったらどうするか。Memory provider を交換したとき、依存する agent をどこまで再起動するか。Permission component を差し替えた瞬間に、古い capability を参照した task が走り続けたらどうするか。自己改修に失敗し、その改修を行った process 自体が壊れたらどう回復するか。

時空間合成可能性は、この問題を「自己改修できる AI」という特殊問題ではなく、**動的 Component System の lifecycle 問題**として捉え直す道具になる。

- Effect を追跡し、自己改修前の状態へ対象 Component だけ戻せる
- Coeffect を宣言し、provider の置換に affected Component だけ追従させる
- final configuration が同じなら、変更履歴によらず同じ quiescent state へ近づける
- Component 単位の failure を他 Component へ波及させず、途中 Effect は回収する

という性質は、長時間稼働しながら自身を変更する Agent Runtime にそのまま欲しくなる。

ただし、ここは **論文による実証結果ではない**。論文は self-evolving agent harness を将来の重要な validation target として挙げているだけであり、Cordis が実際の AI agent harness でこれらを達成したという評価はまだ示されていない。

## まとめ

Spatiotemporal Composability の核心は、動的な Component を「ロードできるコード」としてではなく、**環境への作用・環境への要求・環境への提供を一つの lifecycle boundary に閉じ込めた存在**として扱うことにある。

時間方向では、各 Effect に inverse を対にして runtime が合成し、Component が残した痕跡を回収する。

空間方向では、Dependency を Coeffect として宣言し、provider の出現・消失・置換を lifecycle transition へ変換する。

その二つを Context で統合すると、Component の load / unload、dependency resolution、nested component、HMR、configuration reconciliation が、別々の例外処理ではなく同じ規則で説明できるようになる。

特に価値があるのは、**「正しく cleanup する」「正しい順序で止める」を各 Component 作者の注意力から runtime の構造へ移そうとしていること**である。

一方で、inverse の正しさ、外界へ出た不可逆な出力、悪意あるコードの Sandbox、dependency cycle、version compatibility までは自動的に解決されない。

だからこれは万能な rollback framework ではない。

むしろ、動的なソフトウェアを安全に成長・交換させるために、**何を Component boundary の内側に置けば構造的に保証でき、何が外側に残るのかを明確にするプログラミングパラダイム**として捉えるのが近い。

## 参考資料

- Yifan Shi, Wei Zhang, Tianyi Cui, *A Programming Paradigm for Spatiotemporal Composability*, Peking University / DeepSeek-AI.
- 原文PDF: `[[09_References/Spatiotemporal Composability/A Programming Paradigm for Spatiotemporal Composability.pdf]]`
