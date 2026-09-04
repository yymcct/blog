+++
title = 'Python 依赖管理进化史：从 pip 到 uv'
slug = 'python-dependencies-the-road-to-uv'
date = 2026-04-07T13:01:10+08:00
+++

## 背景
我有 C、.NET、Java 的开发背景，Python 语法基本属于看一眼就能上手的类型，但一直没有系统了解过。对 Python 的开发环境，之前的认知仅限于：venv 管虚拟环境、pip 装包、requirements.txt 管依赖。

最近在读 Microsoft Agent Framework 的源码，发现它用 uv 和 poe 构建，于是决定顺着这条线把 Python 的依赖管理好好梳理一遍，顺便把笔记整理出来，分享给大家。

---
## UV 是什么？

简单粗暴地理解：**uv 就是一个用 Rust 重写的、快得离谱的pip + pip-tools + pyenv 的集合体。** 它整合了以下这些工具的功能：

- **pip / pip-tools**：包安装与依赖解析
- **virtualenv / venv**：虚拟环境管理
- **pipx**：全局安装 CLI 工具
- **poetry**：项目依赖与打包管理
- **twine**：包发布

不过要真正理解 uv 好在哪里，得先把它所取代的这些工具各自过一遍，知道它们解决了什么问题、又留下了什么麻烦。

---
## 关于 pip

pip 是 Python 最基础的包管理工具，常用操作就这几条：

- **安装包：** `pip install <包名>`
- **通过文件批量安装：** `pip install -r requirements.txt`
    
    > 这是项目部署的标准做法，会自动安装文本文件中列出的所有库。
    
- **生成依赖清单：** `pip freeze > requirements.txt`
    
    > 它会扫描当前环境所有已安装的包，按 `包名==版本号` 的格式写入文件。
    

简单直接，但问题也很明显：`pip freeze` 出来的是当前环境里所有包的快照，包括各种子依赖，你根本分不清哪些是你直接需要的，哪些是被别的包拉进来的。

---
##  关于 pip-tools

接触 pip-tools 之前我不太了解它，了解之后发现它对依赖的管理思路要严谨得多。

### 核心逻辑：把"人读的需求"和"机读的环境"分开

- **`pip-compile`：生成确定性的依赖锁**
    
    你只需要创建一个 `requirements.in` 文件，里面写你直接需要的包（比如 `requests`）。运行 `pip-compile` 后，它会自动算出 `requests` 及其所有深层子依赖的精确版本，生成一份 `requirements.txt`。
    
- **`pip-sync`：同步环境**
    
    它会确保你的虚拟环境**完全等同于** `requirements.txt` 的描述——多装了别的包会删掉，少了的会补上。
    

### 标准工作流

引入 pip-tools 之后，就不再推荐直接 `pip install` 了，而是：

> 在 `requirements.in` 中填入新包名 → 执行 `pip-compile` 生成新的 `requirements.txt` → 执行 `pip-sync`

**第一步：编写核心需求 (`requirements.in`)**

```
django>=4.0
psycopg2-binary
requests
```

只写你直接关心的包，框架类指定版本范围，工具类库可以不写版本或只限制大版本。

**第二步：编译锁定文件**

```bash
pip-compile requirements.in
```

生成的 `requirements.txt` 还会附带注释，告诉你每个子依赖是由哪个主包引入的（比如 `certifi` 是由 `requests` 带进来的），一目了然。

**第三步：同步到当前环境**

```bash
pip-sync
```

执行完之后，Python 环境会非常"干净"，只有 `requirements.txt` 里定义的包，没有任何多余的东西。

---
## 关于 venv

venv 是 Python 官方内置的虚拟环境工具，从 3.3 版本起就集成在标准库里，不需要额外安装。它的作用是给每个项目创建一个完全隔离的 Python 运行环境，避免不同项目之间的包版本打架。

### 核心操作

```bash
# 创建环境
python -m venv .venv

# 激活环境（这一步是核心，激活后所有 pip 操作都在这个环境内）
source .venv/bin/activate

# 退出环境
deactivate
```

### 配合 pip-tools 的工作流

把 venv 和 pip-tools 结合起来，基本就达到了"工业级"的标准：

1. `python -m venv .venv` — 创建环境
2. `source .venv/bin/activate` — 激活
3. `pip install pip-tools` — 装工具
4. 编写 `requirements.in`
5. `pip-compile requirements.in` — 编译锁文件
6. `pip-sync` — 同步环境

流程不算复杂，但步骤多、全靠手动维护，还是有点繁琐。

---
## 关于 Poetry

了解了 `pip-tools` 和 `venv` 之后，再理解 Poetry 就很轻松了。

如果说 `venv + pip-tools` 是你自己组装的一套精密零件，那 **Poetry 就是一台开箱即用的一体化跑车**——包管理、依赖锁定、虚拟环境管理、项目打包发布，全部集成在一个工具里。

### 核心优势

- **单一配置文件：** 告别 `requirements.txt`、`setup.py`、`requirements.in` 各管一摊的混乱局面，全部统一写进 **`pyproject.toml`**（这是现代 Python 的标准格式）。
- **确定性锁定：** 自动生成 `poetry.lock`，比 pip-tools 的 txt 文件更详细，确保任何人在任何机器上安装的依赖完全一致。
- **自动管理虚拟环境：** 不需要手动 `python -m venv`，Poetry 会根据项目自动创建和管理。
- **干净卸载：** 移除一个包时，Poetry 会自动清理它带进来的、其他包不再需要的子依赖。这一点比 pip 强太多了。

### 核心指令

```bash
# 新建项目（自动创建目录结构）
poetry new my-project

# 在现有项目中初始化
poetry init

# 添加依赖（自动修改配置、更新 lock、安装到虚拟环境，一步到位）
poetry add requests

# 添加开发依赖（生产部署时不会安装这些）
poetry add pytest --group dev

# 移除依赖
poetry remove requests

# 根据 lock 文件一键还原环境
poetry install

# 在虚拟环境中运行脚本
poetry run python main.py

# 进入虚拟环境的交互式 Shell
poetry shell
```

### 完整工作流

**项目启动**

```bash
# 方式 A：从零新建
poetry new my-app
cd my-app

# 方式 B：在已有代码库中引入
cd existing-project
poetry init  # 交互式生成 pyproject.toml
```

**开发阶段**

```bash
poetry add requests                     # 添加生产依赖
poetry add pytest black --group dev     # 添加开发依赖
poetry show --tree                      # 查看完整依赖树，非常直观
```

**运行代码**

不需要手动激活虚拟环境，直接：

```bash
poetry run python main.py   # 推荐：单次执行，完成即退出
poetry shell                # 如果你习惯传统的 activate 方式
```

**团队协作**

把 `pyproject.toml` 和 `poetry.lock` 都提交到 Git。同事拉取代码后只需：

```bash
poetry install
```

Poetry 会读取 lock 文件里的精确版本哈希，确保安装结果和你的一模一样。

**生产部署**

```bash
# 只安装生产依赖，跳过 dev 组
poetry install --only main
```

### 一个小坑

Poetry 默认把虚拟环境存在全局缓存目录（比如 `~/.cache/pypoetry`），对习惯在项目根目录看到 `.venv` 的人来说有点不习惯。建议加这个配置：

```bash
poetry config virtualenvs.in-project true
```

之后 `poetry install` 就会在项目根目录生成 `.venv` 了，顺眼很多。

---
## 关于 uv

走到这里，依赖管理的"进化之路"算是走完了一半。而 **uv** 就是这段旅程目前的终点。

uv 是由 Astral 公司（就是开发 Ruff 那个公司）用 **Rust** 编写的 Python 包管理器。它的目标不是增加选项，而是**用一个工具取代上面提到的所有工具**。

### 为什么 uv 现在这么火？

一句话：**它太快了。**

- 比 pip 快 10 到 100 倍。pip 装个大依赖可能要 10 秒，uv 基本秒完。
- 集成了 pip、pip-tools、venv、poetry、甚至 pyenv（管理 Python 解释器版本）的全部功能。
- 单文件二进制，不依赖 Python 就能运行，彻底解决了"装 Python 还得先有 Python"的先有鸡还是先有蛋问题。

### 一个顶五个

**① 代替 pyenv：自动安装 Python 解释器**

```bash
uv python install 3.12
```

**② 代替 venv：秒级创建虚拟环境**

```bash
uv venv
```

**③ 代替 pip：闪电安装**

```bash
uv pip install requests
```

uv 还会利用全局缓存——如果另一个项目装过同一个包，它会直接硬链接过来，几乎不占额外空间。

**④ 代替 Poetry / pip-tools：现代化项目管理**

```bash
uv init          # 初始化项目
uv add requests  # 添加依赖
uv sync          # 生成 uv.lock，极速同步环境
```

### 横向对比

|特性|venv + pip|pip-tools|Poetry|**uv**|
|---|---|---|---|---|
|实现语言|Python|Python|Python|**Rust（极快）**|
|管理 Python 解释器|❌ 需手动|❌ 需手动|❌ 需手动|✅ 支持|
|虚拟环境|✅ 手动|❌ 需配合|✅ 自动|✅ 自动且极速|
|锁定文件|❌ 无|✅ txt|✅ lock|✅ lock（更可靠）|
|脚本运行|❌|❌|✅|✅ `uv run`|

### 日常使用指令速查

**项目初始化**

```bash
uv init my-app       # 新建项目（生成 pyproject.toml、hello.py、.python-version）
uv init              # 在现有目录初始化
uv python pin 3.12   # 锁定 Python 版本，本地没有的话 uv 会自动下载
```

**依赖管理**

```bash
uv add requests               # 添加生产依赖
uv add "fastapi>=0.100"       # 添加带版本限制的依赖
uv add --dev pytest ruff      # 添加开发依赖
uv remove requests            # 移除依赖
uv lock --upgrade             # 更新所有依赖到最新版本
```

**运行代码**

```bash
uv run main.py                      # 直接运行，uv 会自动确保环境已同步
uv run python -m my_module --arg1   # 运行模块
uv run python                       # 进入交互式 REPL
source .venv/bin/activate           # 如果你还是习惯手动激活（uv 默认就在项目目录建 .venv）
```

**临时工具，用完即走**

```bash
uvx ruff check .                              # 临时跑 Ruff，不写进项目依赖
uvx --with django django-admin startproject myproj  # 在临时环境中运行，结束后不留痕迹
```

**团队协作**

```bash
uv sync    # 根据 uv.lock 同步本地环境，多了的删、少了的装
uv tree    # 查看依赖树，排查版本冲突很好用
```

**单文件脚本（PEP 723）**

这是 uv 一个挺有意思的特性——如果你只是写个小脚本但需要第三方库，不想专门建一个项目：

```python
# /// script
# dependencies = ["requests", "rich"]
# ///
import requests
...
```

直接 `uv run tool.py`，uv 会自动创建临时环境、安装依赖、运行脚本，完全不污染你的项目环境。

**维护清理**

```bash
uv cache clean    # 清理不再使用的缓存
uv python list    # 查看本地所有 Python 解释器状态
```
