# Parallel Decisions API ナレッジ

調べた日：2026年11月2日
きっかけ：X に投稿された「RAG for decision models」という紹介画像（Python のコード例つき）

## 1. 概要

Parallel Decisions API は、ウェブ検索の API を作っている Parallel Web Systems が、2026年10月下旬に公開した API です。「はい／いいえ」や選択肢で答える質問を送ると、API がその場でウェブから根拠を集め、型の決まった答えと確率、根拠の URL を返します。

要点は次の3つです。

- 答えは文章ではなく、確率や選んだラベルのような値で返る
- 判断の材料をウェブから集めるので、最近の出来事にも答えられる
- 答えを出せない質問には、エラーではなく `refusal` を返す

## 2. 理解に必要な前提

### 決定モデル

2026年9月ごろから、「決定モデル」と呼ばれる種類の AI が出てきました。TypeSafe AI が出した Jev が最初の例で、TypeSafe は「System One モデル」と呼んでいます。

ふつうの LLM は文章を書きますが、決定モデルは文章を書きません。渡された文章やデータ（`state`）と、型の決まった質問を受け取り、確率や選んだ選択肢だけを返します。そのため、速く安く動きます。

一方で、決定モデルが知っているのは、学習したデータと渡された `state` だけです。最近変わった事実には答えられません。

### 質問の3つの型

決定モデルの質問には、次の3つの型があります。Jev と Parallel Decisions API で共通です。

| 型 | 聞くこと | 返る値 |
|---|---|---|
| `noul` | ひとつの条件が正しいか | 「はい」の確率（0〜1） |
| `choice` | 並べた選択肢のどれに当たるか | 選んだラベルと、選択肢ごとの確率 |
| `score` | 順番のある段階のどこか | 段階の番号を確率で重みづけした平均 |

`noul` は Bernoulli（ベルヌーイ分布）から来た名前です。

## 3. 解説

### 仕組み

Decisions API は決定モデルと同じ形の質問を受け取り、ウェブから材料を集めてから判断します。紹介画像の見出しの「RAG for decision models」は、この組み合わせを指しています。

```
あなたのプログラム
 │ state（共通の前提）
 │ ＋ 名前を付けた質問（questions）
 ▼
Decisions API
 ├ ① ウェブから根拠を集める
 └ ② 根拠をもとに判断する
 ▼
answers（質問ごとの答え）
＋ citations（呼び出し全体の根拠）
```

### リクエストの形

```python
response = requests.post(
    "https://api.parallel.ai/v1/decisions",
    headers={"x-api-key": os.environ["PARALLEL_API_KEY"]},
    json={
        "state": {"company": "Clay", "website": "https://www.clay.com"},
        "questions": {
            "has_cli": {
                "type": "noul",
                "instructions": "Does Clay offer an official CLI?",
            }
        },
    },
    timeout=30,
)
```

- `state` は、すべての質問に共通する前提です。決まった形はありません。
- `questions` には質問を名前付きで並べます。名前は自分で付けます。
- 1回のリクエストに100問まで入れられます。どの質問も同じ検索結果を材料にします。
- `timeout=30` は Python 側の設定で、API への指示ではありません。

### 答えの読み方

- 答えは送ったときの名前で取り出します（`answers["has_cli"]`）。
- `noul` の値は「はい／いいえ」ではなく確率です。どこから「はい」と扱うかは、使う側が決めます。
- どの質問も `{"type": "refusal"}` で返ることがあります。これは正常な返事なので、`raise_for_status()` では止まりません。先に `type` を確かめます。
- `choice` や `score` の答えには `noul` の値がありません。型を混ぜるときは、`type` を見て読む場所を分けます。紹介画像のコードはすべての答えから `noul` を読むので、`noul` 以外の型を混ぜると止まります。
- `citations` は呼び出し全体の根拠です。どの URL がどの答えを支えているかは返りません。

### 新しい点

Parallel は決定モデルの弱点として次の3つを挙げ、Decisions API でそれを補ったとしています。

- 最近の事実を知らない
- 答えの理由を示さない
- 「分からない」と答えられない

Parallel のブログでは、Parallel が欧州でのデータ保管に対応したかを Jev に聞くと「いいえ」（確率0.86）と答え、Decisions API は公式ページを根拠に「はい」と答えた例を出しています。

## 4. 似たものとの違い

| | 判断の材料 | 根拠の URL | 型の名前 |
|---|---|---|---|
| Jev（TypeSafe AI） | 渡した `state` だけ | 返らない | noul / choice / score |
| OpenAI Decisions API | 渡した材料（文章や画像） | 返らない | predicate / choice / score |
| Parallel Decisions API | `state` ＋ ウェブで集めた根拠 | 返る | noul / choice / score |

OpenAI も2026年10月に Decisions API を正式に公開しました。質問を配列で並べるなど細かい違いはありますが、渡した材料を型の決まった答えで返す考え方は同じです。質問の形はこの数か月で各社に広がっていて、Parallel Decisions API は、その形にウェブ検索と根拠を足したものと見ると分かりやすくなります。

## 5. 会話でわかったこと

### 速さについて

- Parallel は、1回の呼び出しが1秒未満だとしています。ブログの例は0.5〜0.9秒ほどでした。
- 検索を挟むぶん、手元の文章だけで判断する決定モデルよりは時間がかかります。
- ふつうの LLM より速いという比較は、Parallel のブログには出てきません。

### メタ検索エンジンと組み合わせて速くなるか

RustXNG（SearXNG を Rust で書き直したメタ検索エンジン）と組み合わせて速くなるかを検討しました。結論は、速くなる見込みは小さい、です（会話での検討）。

- Parallel はウェブを自前で集めた索引を持っています。Decisions API の検索もおそらくこの索引を使っています（推測）。
- メタ検索エンジンは検索のたびに外部の検索サイトへ問い合わせます。全体の時間は遅いサイトに引きずられやすくなります。
- メタ検索エンジンの結果はタイトル、URL、短い抜粋が中心です。ページから根拠を抜き出すには、ページを取りに行く処理が別に要ります。
- Decisions API の時間のうち、検索にかかる時間は公開されていません。

組み合わせる意味が出るとすれば、速さではなく情報の新しさです。索引にまだ入っていない数分前のニュースは、その場で外部サイトに聞くほうが拾える可能性があります（推測）。

### 使いどころ

Decisions API が向いているのは、判断に要る事実が手元になく、ウェブ上にあって、時間とともに変わる場面です。根拠を人に見せる必要がある場面も含みます。

```
判断に要る事実はどこにある？
 ├ 手元の文章やデータ → 決定モデル
 └ ウェブ上
    ├ 最近変わりうる   → Decisions API
    └ 根拠を見せたい   → Decisions API
```

場面の例は次のとおりです。

- 顧客管理の会社データの更新（従業員数の帯、出資者など）
- 取引先の情報の見直し（Parallel は426社を10秒足らずで確かめ直し、警告の98%が正しかった例を出している）
- 決まりや制度が今も有効かの確認
- 投稿や記事の内容の事実確認
- 依存パッケージが今も更新されているか、脆弱性が報告されていないかの確認（会話での検討）
- エージェントが書いたコードの関数やモデル名が今も使えるかの確認（会話での検討）

Decisions API が力を出すのは、プログラムの中で何百件、何千件と同じ確認を回す場面です。1件だけ確かめるなら、検索付きのチャットで足ります。

| 確かめたいこと | 合う道具 |
|---|---|
| 投稿1件の真偽 | 検索付きのチャット |
| 主張の背景を原典まで | 原典をたどる調査（芋づる式の調べ方） |
| 大量の投稿を自動で | Decisions API |

### コーディングエージェントの人間承認の判断をログに残したい場合

エージェントの判断は中から見えないので、間に決定モデルを挟み、承認が要るかの確率をログに残す使い方を検討しました（会話での検討）。

この判断では、材料（決めた線引きと、これからする操作の中身）が手元にあります。そのため、Decisions API よりも、ウェブを見ない決定モデル（Jev や OpenAI Decisions API）が合います。Decisions API はウェブから材料を集めるので、時間が増え、関係のない根拠が混ざるおそれがあります。

```
エージェントが操作を決める
 ↓ 実行の直前（エージェントの外で）
決定モデルに聞く
 state：線引き＋操作の中身
 質問：線引きの項目ごとに noul
 ↓
確率をログに残す
 ├ 線より上 → 人の承認へ
 └ 線より下 → そのまま実行
```

- 線引きの項目ごとに質問を分けると、どの項目で引っかかったかがログに残ります。
- 感覚とずれた例には自分で正解を付けて残します。
- 線の位置を動かして直せるのは、点数の順番は合っていて、線の位置だけがずれている場合です。点数が入り交じっているなら、質問の文や `criteria` の定義を書き直します。
- 自動的に良くなるわけではありません。ログを見て直す作業が速く確実になる、という効果です。
- 線引きにウェブ上の事実が入る項目（パッケージのライセンスなど）だけは、Decisions API が生きます。

## 6. 未解決事項

- Decisions API の中で動いている判断のモデルは公開されていない。Jev を使っているかは分からない
- 1回の呼び出しのうち、検索と判断にそれぞれ何秒かかっているかは公開されていない
- Parallel の索引に新しいページが入るまでの時間差は確かめていない
- `choice` と `score` の書き方（選択肢の数や段階の数）は、Parallel の公式の型の説明ページではなく、外部の解説から確かめた
- Jev が「分からない」に当たる返事を持つかは確かめていない。Jev の `noul` では、0.5 前後が「判断がつかない」を表すとする解説がある

## 7. 参考資料（2026年11月2日に確認）

- Introducing the Parallel Decisions API（Parallel ブログ、2026年10月25日）https://parallel.ai/blog/decisions-api
- Decisions API Quickstart（Parallel ドキュメント）https://docs.parallel.ai/decisions/decisions-quickstart
- Parallel Search API 製品ページ https://parallel.ai/products/search
- Parallel の公開告知（X、2026年10月27日）https://x.com/p0/status/2115111877558898931
- Jev introduces a new shape of LLM（Simon Willison、2026年9月21日）https://simonwillison.net/2026/Sep/21/jev/
- What is Jev?（Sanity 用語集）https://www.sanity.io/glossary/jev-typesafe-ai-model
- Parallel Decisions API の統合の提案（AutoGPT Issue #16307）https://github.com/Significant-Gravitas/AutoGPT/issues/16307
- OpenAI Decisions API の解説（cellcog.ai）https://cellcog.ai/blog/openai-decisions-api/
- RustXNG（GitHub）https://github.com/sahenjp/RustXNG

## 8. 更新履歴

- 2026年11月2日：作成
