# System Boundary and Recoverability

## 概要

「副作用を元に戻せる」と言うと、あらゆる処理を完全に rollback できるように聞こえる。しかし *A Programming Paradigm for Spatiotemporal Composability* は、そこまで強いことを主張していない。

[[Revertible Effects]] が回復できるのは、**system が自分で追跡し、排他的に変更し、以前の状態へ戻せる範囲**である。論文はこれを system boundary として扱う。

## Boundary の内側と外側

ある location が boundary の内側にあるとは、system がその location を制御し、変更前の状態へ回復できることを意味する。

逆に、system 外の actor も同じ場所を書き換えたり、一度外へ出した情報を回収できなかったりする場合、その操作は boundary の外側にある。

たとえば、

- private な memory region は内側にできる
- 他 process と共有する memory は外側になりやすい
- private scratch file は内側にできる
- 他 program も読み書きする file は外側になりやすい

というように、媒体そのものではなく **その location をどこまで control できるか**で境界が決まる。

## Acquisition と Emission を分ける

外部 resource へアクセスする操作は、論文では二段階に分けて考えられる。

### Acquisition

Resource へアクセスするための handle を system 内に作る段階。

- `open` が file descriptor を作る
- `malloc` が allocation record を作る
- `fork` が child process record を作る

この record は system が追跡でき、`close`、`free`、`kill` のような inverse を持てる。そのため acquisition は Revertible Effect として扱える。

### Emission

その handle を通して、system 外へ情報を送り出す段階。

- file へ bytes を write する
- network へ packet を send する
- 外部 API へ request を送る

一度 external world へ出た情報は、system の Context だけを巻き戻しても消えない。ここは boundary の外側になる。

この区別は、動的 system の「回復」を考えるときに重要である。**Resource を取得したことは戻せても、その resource を通して世界へ与えた影響までは戻せない場合がある。**

## 外部作用には withholding か compensation が必要

Emission まで回復させたい場合、論文は二つの方向を挙げる。

一つは **withholding**。結果を確定させてよいと分かるまで external emission を保留する。Rollback recovery における output commit problem に近い。

もう一つは **compensation**。完全な inverse ではなく、application が「意味的には元に戻った」と見なせる別操作を行う。

たとえば、

- 作成した file を削除する
- charge を refund する

といった操作である。

ただし compensation は、[[Context Paradigm]] が使う observational equivalence より粗い equivalence を導入しうる。そのため、Revertible Effects の形式保証をそのまま移植できるわけではなく、別途その equivalence 上で性質を確認する必要がある。

## Access Control と Sandbox

Context を通した dependency access は、宣言した capability だけを利用させる仕組みとして使える。

Component が `filesystem` を dependency として要求し、さらに Interception metadata で read-only path だけを許す、といった制御ができる。

しかし、Component が信頼できない code なら、それだけでは足りない。Host runtime の object へ直接到達できれば、Context mediation を迂回できるからである。

そのため論文は、untrusted component には言語レベルの policy とは別に、

- software fault isolation
- separate language runtime
- sandboxed process
- virtualized container

などの execution boundary が必要だとする。

ここで Context は access policy を記述する層、sandbox は **その policy を迂回できないようにする実行境界**として役割が分かれる。

## OS と共同設計すると何が変わるか

論文は将来像として、Operating System 自体が Context Paradigm を支援する可能性も述べる。

OS はもともと memory、file descriptor、process などの resource acquisition を記録している。もしそれらを Component ごとの Coeffect として提供できれば、runtime が同じ resource tracking を二重に実装する必要がなくなる。

さらに copy-on-write や transactional storage を利用すれば、通常は boundary の外側に近い persistent operation の一部も rollback 可能にできる。

つまり system boundary は固定ではない。**どこまでを runtime が reify し、追跡し、inverse を提供できるかによって動かせる**。

ただし、境界を内側へ広げるほど、各 access を mediation する cost も増える。この trade-off まで含めて system design の問題になる。

## 関連

- [[Spatiotemporal Composability]]
- [[Revertible Effects]]
- [[Reactive Coeffects]]
- [[Context Paradigm]]
- [[Dynamic Component Lifecycle]]
- [[Cordis]]

## 参考資料

- Yifan Shi, Wei Zhang, Tianyi Cui, *A Programming Paradigm for Spatiotemporal Composability*, Peking University / DeepSeek-AI.
- 原文PDF: `[[09_References/Spatiotemporal Composability/A Programming Paradigm for Spatiotemporal Composability.pdf]]`
