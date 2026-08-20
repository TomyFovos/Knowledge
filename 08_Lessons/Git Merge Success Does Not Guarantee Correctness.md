# Git Mergeの成功は正しいマージを保証しない

Status: Adopted

#lesson

## 概要

Gitでマージがコンフリクトなしに成功したとしても、**マージ結果が意味的に正しいことまでは保証されない**。

`marcbrooker/git_weirdness` では、現在のGitで実際に発生する反例として、通常の `git merge` が終了コード0・コンフリクトなしで完了しながら、入力には存在しない変更を重複適用してしまうケースが示されている。

重要なのは、これは「Gitがコンフリクトを検出しすぎる」という安全側の失敗だけではなく、**誤った内容を正常なマージ結果として返す可能性がある**という点である。

> Git merge success ≠ semantic correctness

## なぜ重要か

通常の開発では、マージ成功を次のように扱いがちである。

```text
merge
  ↓
conflictなし
  ↓
成功
```

しかし実際には、Gitが保証しているのは主にテキスト上の統合が実行できたことであり、変更意図やプログラムの意味まで保証しているわけではない。

特に次のような環境では重要になる。

- AI Agentが複数ブランチ・worktreeで並列実装する
- Multi-Agentで変更を大量に自動生成する
- 自動マージ後、人間のレビューを介さず次工程へ進む
- CI/CDでマージ成功そのものを品質ゲートとして扱う
- 同じようなコード・設定・定義が繰り返されるファイルを編集する

AI駆動開発ではマージ回数そのものが増えるため、低確率の問題であっても遭遇可能性が上がる。

## 実証されている現象

`git_weirdness` の最小反例では、Base / Left / Right が次のようになっている。

### Base

```text
a
b
b
b
```

### Left

```text
a
b
a
b
b
```

Baseに `a` を1行挿入している。

### Right

```text
b
a
b
a
b
b
```

Baseに先頭の `b` と `a` を挿入している。

このケースをGitの標準マージ戦略 `ort` でマージすると、コンフリクトなしで次の結果になる。

```text
b
a
b
a
b
a
b
b
```

8行になっており、`a` が1つ余計に生成されている。

挿入しか行っていない場合、妥当なthree-way mergeが各ブランチの挿入を1回ずつ適用するなら、結果の最大長は次式で求められる。

```text
|Left| + |Right| - |Base|
= 5 + 6 - 4
= 7
```

しかしGitは8行を生成する。

つまり、**変更を重複適用しているにもかかわらず、コンフリクトとして検出されない。**

## 原因

three-way mergeでは、Baseを基準にLeftとRightの差分を計算し、それぞれの変更を統合する。

概念的には次の形になる。

```text
        Base
       /    \
    diff    diff
     /        \
  Left       Right
       \    /
        merge
```

問題になるのが、次のような重複行である。

```text
b
b
b
```

同じ行が複数存在すると、diffアルゴリズムには「どの `b` とどの `b` を対応させるか」という曖昧さが生じる。

Gitの標準 `ort` merge strategy は内部diffに `histogram` アルゴリズムを使用する。

`histogram` は高速性や人間に読みやすいdiffを得るためのヒューリスティックを持つ一方、常に最大マッチングを求めるわけではない。

その結果、LeftとRightで本来関連する変更が曖昧な繰り返し領域の別々の位置にアンカーされ、Gitがそれらを独立した変更と判断して両方を適用することがある。

## diffアルゴリズムによる違い

この最小反例では次の結果になる。

| diff algorithm | 結果 |
| --- | --- |
| `histogram` | 誤った8行を生成 |
| `myers` | 正常 |
| `minimal` | 正常 |
| `patience` | 正常 |

したがって、この反例はGitのthree-way mergeという考え方そのものだけではなく、**実装上のdiffアルゴリズム選択によって安全性が変化する**ことも示している。

ただし、別アルゴリズムに変更すればあらゆるマージが正しくなる、という意味ではない。

## diff3研究との関係

このリポジトリは2007年の論文 *A Formal Investigation of Diff3* を背景にしている。

同論文ではdiff3について、直感的には独立して見える離れた変更でも不要なコンフリクトが発生することや、idempotent・stableではないことなどが形式的に示されている。

ただし論文ではdiffがmaximum non-crossing matchingを返すことを前提としているため、主に扱われるのは次のような安全側の失敗である。

```text
本当はマージ可能
    ↓
CONFLICT
```

一方、実際のGitでは性能・可読性上の理由からその前提を満たさないdiffアルゴリズムが使われる場合があり、次のようなより危険な失敗が発生し得る。

```text
本当はその結果にならない
    ↓
CONFLICTなし
    ↓
誤ったマージ結果
```

## git_weirdness の特徴

このリポジトリは単なる不具合報告ではなく、再現・探索・最小化まで含んでいる。

### `examples/minimal/`

Gitが誤ったclean mergeを生成する最小反例。

### `fuzz.py`

Base / Left / Rightをランダム生成し、unsoundなmergeを探索するFuzzer。

挿入のみのケースについて、

```text
merged length <= |L| + |R| - |O|
```

という性質をOracleとして利用し、この上限を超えるclean mergeを「内容を発明・重複した」と判定する。

### `minimize.py`

反例を総当たり探索し、問題が発生する最小入力を求める。

リポジトリでは、二値アルファベットに対してBase長4・合計3 insert（1 + 2）が最小反例として示されている。

### `examples/locality/`

2007年のdiff3論文にある、離れた編集にもかかわらず不要なconflictが発生するlocality counterexampleを現在のGitで再現する。

## 実務上の教訓

### 1. merge成功を品質ゲートにしない

次の判定は不十分である。

```text
git merge
exit code = 0
      ↓
変更は正しい
```

マージ成功は、後続の検証へ進んでよい条件の1つとして扱う。

### 2. 自動マージ後にテストを実行する

最低でも次の形にする。

```text
Git merge
   ↓
Build
   ↓
Unit Test
   ↓
Integration Test
   ↓
Static Analysis
   ↓
必要に応じて生成物・振る舞いの検証
   ↓
Accept
```

### 3. AI Agentでは「変更意図」とマージ結果を照合する

AI Agentが並列開発する場合、テストだけでは検出できない誤マージも考えられる。

理想的には、各Agentが持つ変更意図・要求・編集対象と、最終マージ結果を照合する。

```text
Agent A intent ─┐
Agent B intent ─┼─→ merged result verification
Agent C intent ─┘
```

例えば次を検証対象にできる。

- Agentが追加したはずの変更が存在するか
- 同じ変更が複数回適用されていないか
- Agentが触っていない領域に想定外の変更がないか
- 最終成果物が要求・設計を満たしているか

### 4. テストは「コードが動くか」だけではない

AI駆動開発では、mergeそのものも信頼境界として考える必要がある。

```text
生成
↓
編集
↓
マージ
↓
ビルド
↓
テスト
↓
成果物
```

各工程で、前工程の結果が正しいという前提を無条件に置かない。

## AI駆動開発への示唆

Multi-Agent開発では、次のような構成が一般化する可能性がある。

```text
                 ┌─ Agent A ─ branch/worktree A
Requirement ────┼─ Agent B ─ branch/worktree B
                 └─ Agent C ─ branch/worktree C
                           ↓
                         merge
                           ↓
                       final branch
```

ここでGitを単なる安全な統合器として扱うと、

```text
merge conflictなし
= 統合成功
= 実装成功
```

という誤った推論につながる。

より安全なHarnessでは、次のように扱うべきである。

```text
Agent Output
    ↓
Merge
    ↓
Merge Result Validation
    ↓
Tests / Evaluation
    ↓
Evidence
    ↓
Acceptance
```

つまりGitは**最終的な正しさを保証するコンポーネントではなく、検証対象となる中間工程**として扱う。

これは [[Agent Harness]]、[[Multi-Agent]]、[[AI Driven Development]]、[[Evaluation]]、[[Platform Test]] の設計にも関係する。

## 注意点

この知見から、通常のGit mergeが頻繁に壊れると解釈するのは適切ではない。

重要なのは、**clean mergeであることからsemantic correctnessを論理的に導くことはできない**という点である。

また、今回の具体的なsilent duplicationは特定の入力と `histogram` diffの組み合わせによる反例であり、実際のプロジェクトでの発生頻度とは別の問題である。

したがって実務上の対応は「Gitを使わない」ではなく、

> Gitによる統合結果も、他の自動生成物と同じように検証する

ことになる。

## 関連

- [[Git]]
- [[Three-way Merge]]
- [[AI Driven Development]]
- [[Multi-Agent]]
- [[Agent Harness]]
- [[Evaluation]]
- [[Platform Test]]

## 参考資料

- Marc Brooker, `git_weirdness`  
  https://github.com/marcbrooker/git_weirdness
- Sanjeev Khanna, Keshav Kunal, Benjamin C. Pierce, *A Formal Investigation of Diff3*, FSTTCS 2007  
  https://www.cis.upenn.edu/~sanjeev/papers/fsttcs07_diff3.pdf
- Niels Glodny, *Analyzing and Evaluating the Behavior of Git Diff and Merge*, 2025  
  https://arxiv.org/abs/2507.22071

## 出典リポジトリでの確認環境

`git_weirdness` のREADMEでは Git 2.50.1 (Apple Git-155) で検証したと記載されている。

将来Gitのmerge実装やdiffアルゴリズムが変更された場合、同じ反例が再現するかは再検証する必要がある。
