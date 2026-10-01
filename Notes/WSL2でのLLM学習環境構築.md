# WSL2でのLLM学習環境構築

量子化済みモデルを推論ツールで動かすだけなら、Windows上のアプリで足りる。
しかし、自分でモデルを読み込み、微調整や蒸留を行うなら、PyTorchなどの学習用ライブラリがGPUを使える環境が必要になる。

このノートは、2026-09-20に [[企業専用モデルの学習ロードマップ|企業専用モデルの学習ロードマップ]] のPhase 0-Aとして行った環境構築を整理したものである。
対象はWindows 11とRTX 4070（VRAM 12GB）である。
バージョン番号は会話時点の実行結果であり、今後の環境では変わる。

## 学習環境はWSL2のUbuntuへ分ける

**WSL2（Windows Subsystem for Linux 2）** は、Windows上でLinuxを動かす仕組みである。

会話では、学習用のLabをWindowsネイティブではなくWSL2のUbuntuへ置くことを勧めている。
今後QLoRA、Transformers、PEFT、TRL、bitsandbytes、Unslothなどへ進むことを考えると、学習環境はLinux側へ統一した方が実務環境にも近いためである。
これまでのBonsai環境はそのまま残してよい。

```text
Windows
│
├─ Bonsai
│   └─ 今までのローカルLLM環境
│
└─ WSL2
    └─ Ubuntu
        └─ enterprise-local-ai-lab
             ├─ PyTorch
             ├─ Transformers
             ├─ PEFT
             ├─ TRL
             └─ CUDA
                    │
                    ▼
                RTX 4070 12GB
```

## 最初にWSLとGPUの状態を確認する

PowerShellで次を実行する。

```powershell
wsl --status
wsl -l -v
```

会話時点の結果では、既定のディストリビューションがUbuntu、既定のバージョンが2だった。
`wsl -l -v` では `Ubuntu` と `docker-desktop` が `Stopped` と表示された。
`Stopped` は起動していないだけで、問題ではない。

Ubuntuを開くには、PowerShellで `wsl` と打つ。
スタートメニューで「Ubuntu」を検索する方法や、Windows Terminalのタブ横の `▼` からUbuntuを選ぶ方法でもよい。
成功すると、プロンプトが `PS C:\WINDOWS\system32>` から `username@PCNAME:/mnt/c/WINDOWS/system32$` のようなLinux側の表示へ変わる。

Ubuntu内で次を実行する。

```bash
nvidia-smi
uv --version
python3 --version
```

会話時点の結果は次の通りである。

- `nvidia-smi`：Driver Version 591.86、CUDA Version 13.1、NVIDIA GeForce RTX 4070、12282MiB。
- `uv`：未インストール（`Command 'uv' not found`）。
- Python：3.12.3。

`nvidia-smi` で12,282MiBのVRAMまで認識できていれば、WSL2からRTX 4070が正しく見えている。

この段階ではPyTorchもモデルも入れない。
`nvidia-smi` の結果から、WSLから4070が見えているか、ドライバがどのCUDA世代まで扱えるかを確認し、それに合わせてPyTorchのCUDAビルドを選ぶためである。

## ドライバのCUDA版とPyTorchのCUDA版は別物である

**CUDA**は、NVIDIA GPUで汎用計算を行うための仕組みである。

`nvidia-smi` に表示される `CUDA Version: 13.1` は、そのドライバが対応できるCUDAの上限側を示す。
PyTorchを必ずCUDA 13.1版で入れなければならないという意味ではない。
PyTorchは自分用のCUDAランタイムを配布物に含むため、対応するビルドを選べば動く。

実際に、後でPyTorchから見たCUDAランタイムは13.0になった。
これは矛盾ではない。

```text
Windows NVIDIA Driver
  CUDA 13.1まで対応
          │
          ▼
WSL2
          │
          ▼
PyTorch
  CUDA 13.0 Runtimeを使用
          │
          ▼
RTX 4070
```

**GPUドライバ、CUDA、PyTorchは同じものではない。**
ローカルLLMを扱ううえで頻繁に出てくるため、最初に覚えるべき点とされている。

```text
NVIDIA Driver
        ↓
CUDA Driver API
        ↓
PyTorch CUDA Runtime
        ↓
RTX 4070
```

## 作業ディレクトリはLinux側のホームに置く

Ubuntuを開いた直後は `/mnt/c/WINDOWS/system32` にいる。
ここで開発を始めるのは避ける。

`/mnt/c/...` はWindowsのファイルシステムをWSL越しに扱うため、Linuxネイティブ側よりファイル入出力で不利になりやすい。
今後モデルファイルを何GBも扱うため、地味だが重要である。

```bash
cd ~
mkdir -p ~/projects/enterprise-local-ai-lab
cd ~/projects/enterprise-local-ai-lab
pwd
```

`/home/<ユーザー名>/projects/enterprise-local-ai-lab` になればよい。

## uvでLab専用のPython環境を作る

**uv**は、Python本体、仮想環境、Pythonパッケージ、ロックファイルを高速に管理する道具である。

システムのPythonへ直接 `pip install torch` などを入れていくと、後でプロジェクトごとにtransformersの版や特定のtorchが必要になったときに依存関係が衝突する。
そこで、このLab専用のPython環境を作る。

```text
Ubuntu
│
├─ System Python
│
└─ enterprise-local-ai-lab
       │
       └─ .venv
            ├─ PyTorch
            ├─ Transformers
            ├─ PEFT
            └─ TRL
```

利用者は「Condaと同じようなものか」と確認した。
プロジェクトごとにPython環境を分離するという意味ではCondaに近い。
ただし、CondaはPython以外のネイティブライブラリや環境そのものまで広く管理するのに対し、uvはPython寄りに特化している。
PyTorchとTransformers中心のLabならuvで十分とされている。

インストールはAstral公式のLinux向けインストーラを使う。

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
uv --version
```

まだ `command not found` なら、`~/.local/bin/uv --version` で切り分けられる。
会話時点では uv 0.12.17 が `~/.local/bin` へ入った。

プロジェクトを初期化する。

```bash
uv init
ls -la
```

`.git/`、`.gitignore`、`.python-version`、`README.md`、`main.py`、`pyproject.toml` のようなファイルができる。
**`pyproject.toml`** が、このプロジェクトに必要なPythonライブラリを記録する中心ファイルになる。
`uv init` したプロジェクトでは、必要になった時点で `.venv` が作られ、`uv add` で依存関係が `pyproject.toml` へ記録される。

## PyTorchをCUDA版の配布元から入れる

**PyTorch**は、AIモデルをPythonで作り、学習し、GPUで計算するための基盤ライブラリである。
ChatGPTのようなAIそのものというより、AIを動かす計算エンジンに近い。

```text
自分が書くPythonコード
        │
        ▼
Transformers
「QwenやLlamaなどのLLMを扱いやすくする」
        │
        ▼
PyTorch
「ニューラルネットワークの計算・学習をする」
        │
        ▼
CUDA
「NVIDIA GPUで計算する仕組み」
        │
        ▼
RTX 4070
```

`AutoModelForCausalLM.from_pretrained(...)` と書くのはHugging Face Transformersだが、そのモデルの中身は大量のPyTorchの **テンソル（Tensor）** である。
学習時には、PyTorchが「入力→モデルで計算→誤差を計算→どの重みをどれだけ変えるか計算→重みを更新」を担当する。

ドライバがCUDA 13.1まで対応しているため、CUDA 13.0ビルドのPyTorchを明示して入れる。
会話時点ではPyTorch 2.14.0にLinux/Python 3.12向けの `cu130` 版があった。

```bash
uv add torch --index pytorch-cu130=https://download.pytorch.org/whl/cu130
```

uvは、PyTorch専用のCUDA配布元を `pyproject.toml` へ記録できる。
画像処理はしないため、`torchvision` はまだ入れない。
依存を増やさず、まずtorchそのものを理解するためである。

## PythonからGPUが使えることを確認する

```bash
uv run python -c "import torch; print('PyTorch:', torch.__version__); print('CUDA runtime:', torch.version.cuda); print('CUDA available:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0)); print('VRAM GB:', torch.cuda.get_device_properties(0).total_memory / 1024**3)"
```

`torch.cuda.is_available()` でGPUが使えるかを確認するのが、PyTorch公式の確認方法である。

会話時点の結果は次の通りである。

```text
PyTorch: 2.14.0+cu130
CUDA runtime: 13.0
CUDA available: True
GPU: NVIDIA GeForce RTX 4070
VRAM GB: 11.99365234375
```

Python → PyTorch → CUDA → RTX 4070 まで接続できたことになる。

このとき `UserWarning: Failed to initialize NumPy: No module named 'numpy'` が出た。
これはGPU関連のエラーではなく、仮想環境にNumPyを入れていないだけである。
今後データ処理や評価でも使うため、`uv add numpy` で入れておく。

## Phase 0-Aで確認できたこと

```text
WSL2
 ↓
Ubuntu
 ↓
uv
 ↓
専用Python環境
 ↓
PyTorch
 ↓
CUDA
 ↓
RTX 4070
```

ここまで自分で組めたうえで、次を理解できればPhase 0-Aは完了とされた。

- `nvidia-smi` のCUDA VersionとPyTorchのCUDAランタイムは別物である。
- PyTorchはAI計算の基盤である。
- Tensorが計算の基本単位である。
- TensorをCPUのRAMとGPUのVRAMの間で移動できる。

Tensorの扱いと、その後に行った小さなモデルの学習は [[LLMを理解するためのニューラルネットワーク基礎|LLMを理解するためのニューラルネットワーク基礎]] にまとめている。

次のPhase 0-Bでは、Bonsaiで完成済みGGUFを読み込む代わりに、Hugging Face → safetensors → PyTorch → RTX 4070 の順で、量子化される前のオープンウェイトモデルを直接ロードする予定である。
ここでWeight、Parameter、safetensors、モデルが何GBになる理由が実物としてつながる。

## 関連

- [[企業専用モデルの学習ロードマップ|企業専用モデルの学習ロードマップ]]
- [[LLMを理解するためのニューラルネットワーク基礎|LLMを理解するためのニューラルネットワーク基礎]]
- [[企業向け蒸留モデル|企業向け蒸留モデル]]
- [[必要なときだけGPUを借りてLLMを動かす|必要なときだけGPUを借りてLLMを動かす]]

## 参考資料

- PyTorch, *Start Locally*
- https://docs.pytorch.org/get-started/locally/
- PyTorch, *Previous PyTorch Versions*
- https://pytorch.org/get-started/previous-versions/
- PyTorch Developer Mailing List, *PyTorch 2.14 Final RC Available*
- https://dev-discuss.pytorch.org/t/pytorch-2-14-final-rc-available/3429
- PyTorch, CUDA 13.0 wheel index
- https://download.pytorch.org/whl/cu130/torch/
- Astral, *Installation | uv*
- https://docs.astral.sh/uv/getting-started/installation/
- Astral, *Using environments | uv*
- https://docs.astral.sh/uv/pip/environments/
- Astral, *Commands | uv*
- https://docs.astral.sh/uv/reference/cli/
- Astral, *Using uv with PyTorch*
- https://docs.astral.sh/uv/guides/integration/pytorch/
- 原本：[[Sources/Model Distillation/企業向け蒸留モデルと学習ロードマップの対話記録_20261001-1717.md]]
#lesson
