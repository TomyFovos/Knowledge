# Revertible Effects（可逆な副作用）

## 概要

動的にロードしたコンポーネントを安全に外すには、コードだけ消せても足りない。イベント登録、リソース確保、共有状態の更新、子コンポーネントの起動など、そのコンポーネントが環境へ残した変更も回収できなければならない。

*A Programming Paradigm for Spatiotemporal Composability* では、この問題を **Revertible Effects** として扱う。

通常の Effect が「計算が環境をどう変えるか」を表すのに対し、Revertible Effect は、変更後の状態だけでなく **その変更を戻す inverse（逆操作）**も同時に返す。

```text
e : Γ → Γ × (Γ → Γ)
```

現在の Context `Γ` に Effect を適用すると、変更後の Context と、その変更を撤回する関数が得られる。重要なのは、cleanup を別の場所に後付けするのではなく、**副作用を起こす場所で、その副作用を戻す方法も対にする**ことである。

## 複合的な teardown を runtime に合成させる

一つのコンポーネントは、多数の Effect を順番に実行する。

たとえば、

1. イベントリスナーを登録する
2. ルートを追加する
3. タイマーを開始する
4. 別のコンポーネントを登録する

といった操作を行った場合、それぞれの inverse を runtime が蓄積する。アンロード時には最後に実行した Effect から逆順に適用するため、回復は LIFO になる。

この構造の意味は大きい。コンポーネント作者が「このプラグイン全体をどうアンインストールするか」を別途設計する必要がなくなり、**原子的な Effect にだけ inverse を与えれば、複合的な teardown は合成から導出できる**。

これは、手書きの `deactivate()` や cleanup callback と考え方が違う。cleanup を別のライフサイクル関数に置く方式では、「登録したのに解除を書き忘れた」という漏れが起こりうる。Revertible Effects では、作成と撤回を構造上の対にすることで、この責務を局所化する。

## Effect が混ざると何が難しくなるのか

一つのコンポーネントだけなら、inverse を逆順に適用すればよい。しかし実際のシステムでは、複数コンポーネントの Effect が時間的に入り交じる。

たとえば A が共有状態を書き換え、その後 B が別の変更を加えたあとで、A だけをアンロードしたいとする。A の inverse が B の変更まで巻き戻してしまうなら、コンポーネント単位の回復にはならない。

そこで論文は **independence / commutativity（独立性・可換性）**を導入する。異なるコンポーネントの Effect が独立なら、実行順が入り交じっていても、一方の inverse だけを適用して、そのコンポーネントの寄与だけを取り除ける。

つまり Temporal Composability が必要としているのは単なる Undo Stack ではない。

> 誰の変更なのかを追跡し、他者の変更と混ざったあとでも、その一人分だけを撤回できること。

この性質が、[[Spatiotemporal Composability]] における時間方向の保証になる。

## Iterator と非同期処理

現実のコンポーネント初期化は、一つの原子的な Effect では終わらない。複数ステップを踏み、途中で `await` し、環境が変化することもある。

論文では Effect を iterator として扱えるよう拡張し、各ステップが「変更・inverse・次の処理」を返す形にする。各 iteration の境界で target が変わっていれば、そこまでに蓄積した inverse だけを使って部分的に rollback できる。

非同期処理については、すでに開始した iteration は完了させ、その後で unload に移る **inertia** を採用する。これにより、「途中まで実行された Effect が宙に浮く」状態を避ける。

## Failure も回復経路へ統合する

Effect の実行途中で失敗した場合も、失敗専用の別経路に飛ばすのではなく、それまでに蓄積した accumulator を使って unload と同じ回復経路へ入れる。

失敗した fiber は他の sibling を巻き込まず、その fiber だけが failed 状態になる。つまり failure はシステム全体の失敗ではなく、**コンポーネント単位で隔離された失敗**として扱われる。

## 実装上の重要な限界

Cordis では、すべての Context 変更を `ctx.effect` に通し、そこで返された disposer を accumulator に積む。

ただし、runtime が「この inverse は本当に元の Effect を正しく戻すか」を証明してくれるわけではない。論文の形式モデルでは witnessed effect として正しさを仮定するが、Cordis 実装では **inverse の正しさは Effect 作者の責務**として残る。

そのため Revertible Effects は「何でも自動的に元に戻せる魔法」ではない。むしろ、

- 副作用を Context 経由へ集約する
- 原子的な Effect と inverse を対にする
- runtime がその inverse を追跡・合成する
- コンポーネント間では独立性を満たす

という設計規律によって、回復可能性を構造化する仕組みである。

## 関連

- [[Spatiotemporal Composability]]
- [[Reactive Coeffects]]
- [[Context Paradigm]]
- [[Dynamic Component Lifecycle]]
- [[Cordis]]

## 参考資料

- Yifan Shi, Wei Zhang, Tianyi Cui, *A Programming Paradigm for Spatiotemporal Composability*, Peking University / DeepSeek-AI.
- 原文PDF: `[[09_References/Spatiotemporal Composability/A Programming Paradigm for Spatiotemporal Composability.pdf]]`
