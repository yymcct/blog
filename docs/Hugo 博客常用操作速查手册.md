
# Hugo 博客常用操作速查手册

> 本 README 汇总了使用 Hugo 写博客时最常用的命令和场景，方便随时查阅。

---

## 1. 基础命令

| 命令 | 说明 |
|------|------|
| `hugo version` | 查看当前 Hugo 版本 |
| `hugo help` | 查看所有命令帮助 |
| `hugo server` | 启动本地预览服务器（默认不包含草稿） |
| `hugo server -D` | 启动本地预览并包含草稿（最常用） |
| `hugo server -D --disableFastRender` | 关闭快速渲染（排查模板问题时用） |
| `hugo` 或 `hugo build` | 构建静态网站到 `public/` 目录 |
| `hugo --minify` | 构建并压缩输出文件 |
| `hugo new site 站点名` | 创建新站点 |
| `hugo new content 路径/文件名.md` | 创建新内容 |

---

## 2. 创建内容（最常用）

```bash
# 创建一篇文章（推荐放在 posts 目录）
hugo new content posts/文章标题.md

# 创建关于页面
hugo new content about.md

# 创建独立页面
hugo new content 页面名.md
```

创建后文件默认 `draft = true`，需要手动改成 `false` 才会发布。

### 文章 Front Matter 常用字段示例

```toml
+++
title = "文章标题"
date = 2026-09-03
draft = false
tags = ["Hugo", "博客"]
categories = ["技术"]
description = "文章简介（可选）"
cover = "/images/cover.jpg"   # 封面图（部分主题支持）
+++
```

---

## 3. 本地开发与预览

```bash
# 最常用（包含草稿）
hugo server -D

# 指定端口
hugo server -D -p 1314

# 绑定所有网络接口（方便手机预览）
hugo server -D --bind 0.0.0.0

# 只监听内容变化，不监听主题变化（速度更快）
hugo server -D --disableLiveReload
```

访问地址通常是：`http://localhost:1313/`

---

## 4. 构建网站

```bash
# 正常构建
hugo

# 构建并压缩
hugo --minify

# 清理 public 目录后重新构建（推荐）
rm -rf public && hugo
# Windows PowerShell：
Remove-Item -Recurse -Force public; hugo
```

构建完成后，所有静态文件都在 `public/` 目录。

---

## 5. 主题相关操作

### 添加主题（Git Submodule 方式，推荐）

```bash
git init
git submodule add https://github.com/adityatelange/hugo-PaperMod themes/PaperMod
```

然后在 `hugo.toml` 中添加：
```toml
theme = "PaperMod"
```

### 更新主题

```bash
git submodule update --remote
```

### 切换主题
只需修改 `hugo.toml` 中的 `theme` 值即可。

---

## 6. 配置文件常用设置（hugo.toml）

```toml
baseURL = "https://yourdomain.com/"
languageCode = "zh-cn"
title = "我的博客"
theme = "PaperMod"

# 中文优化
hasCJKLanguage = true

# 分页
paginate = 10

[params]
  description = "博客描述"
  author = "你的名字"
  # 其他主题专属参数请参考对应主题文档
```

---

## 7. 常见实用场景

### 7.1 插入图片
1. 把图片放到 `static/images/` 目录
2. 文章中引用：
   ```markdown
   ![图片描述](/images/xxx.jpg)
   ```

### 7.2 草稿管理
- 新建文章默认是草稿（`draft = true`）
- 本地预览草稿：`hugo server -D`
- 正式发布时把 `draft` 改成 `false`

### 7.3 查看草稿、过期内容等
```bash
hugo server -D          # 包含草稿
hugo server -F          # 包含未来发布的内容
hugo server -E          # 包含已过期内容
hugo server -D -F -E    # 全部包含
```

### 7.4 清理并重新构建
```bash
# Windows PowerShell
Remove-Item -Recurse -Force public, resources
hugo
```

### 7.5 生成站点地图、RSS 等
Hugo 默认会自动生成，无需额外配置（大多数主题已支持）。

---

## 8. 部署相关

本项目使用 **Cloudflare Pages**（参考教程：[将你的 Hugo 免费托管在 Cloudflare Pages](http://www.whohh.cn/posts/hugo-cloudflare-page/)）。

### 原理说明

CF Pages 本质是"Git 触发的自动构建 + CDN 托管"：push 代码到 GitHub → CF Pages 自动克隆仓库 → 按环境变量安装对应版本 Hugo、执行构建命令 → 把输出目录的静态文件发布到 Cloudflare 全球 CDN。全程无需服务器，每次 push 自动触发，构建产物不进 Git。

### Cloudflare Pages 部署步骤（一次性配置）

1. **推送到 GitHub**：把整个 Hugo 项目推上去（不需要 Hugo 二进制文件，`public/` 也无需提交）
2. **创建 Pages 项目**：登录 [dash.cloudflare.com](https://dash.cloudflare.com/) → `Workers 和 Pages` → 创建 → `Pages` → `连接到 Git`
3. **选择仓库**：选 GitHub 账户和对应仓库（看不到仓库时，去 GitHub 的 Settings → Applications 给 Cloudflare Pages 授权，可选全部或单个仓库）
4. **填构建配置**：

   | 配置项 | 值 |
   |---|---|
   | 框架预设 | Hugo |
   | 构建命令 | `hugo`（或 `hugo --minify`） |
   | 输出目录 | `public` |
   | 环境变量 `HUGO_VERSION` | 与本地版本一致（本项目用 `0.165.0`） |

5. 保存并部署，等日志出现 `Success: Your site was deployed!` 即可用 `*.pages.dev` 免费域名访问；建议再绑定自己的域名（项目 Custom domains）

### 注意事项

- **务必设置 `HUGO_VERSION`**：CF Pages 默认 Hugo 版本偏旧，可能缺字段或模板报错（本项目曾因默认 v0.147.7 不支持主题的 `.Site.Language.Locale` 而构建失败）。Production 和 Preview 环境都要设：Settings → Environment variables
- **更新博客**：本地改完 → commit → push 到 GitHub，CF Pages 自动重新构建部署，无需手动操作
- 构建失败时看 Deployments 页面的构建日志，报错信息与本地 `hugo` 输出格式一致

---

## 9. 常用目录结构说明

本项目实际结构：

```
blog/
├── archetypes/          # 新建内容的模板（front matter 默认值）
├── content/             # 所有文章和页面
│   ├── posts/           # 博客文章
│   ├── about.md         # 关于页
│   └── projects/        # 其他栏目
├── assets/              # 需 Hugo 加工的源素材
│   ├── avatar.jpg       # 头像（主题会缩放成多尺寸 webp）
│   ├── icons/           # favicon 全套（覆盖主题同名文件）
│   └── sass/_custom.scss# 自定义样式（覆盖主题）
├── i18n/                # 文案翻译覆盖（en-us.yaml 已置空页脚）
├── themes/awesome/      # 主题目录
├── hugo.toml            # 站点配置文件
├── static/              # （可选）原样复制到 public/ 的文件，本站未使用
├── layouts/             # （可选）模板覆盖目录，本站未使用
├── resources/           # Hugo 构建缓存，自动生成，勿手改（gitignore）
└── public/              # 构建输出目录（gitignore，不提交）
```

### 易混淆的三个目录

| 目录 | 关键区别 | 什么时候用 |
|---|---|---|
| `assets/` | 会被 Hugo **加工**（编译 SCSS、缩放图片、转 webp） | 需要处理的素材，如头像、图标、自定义 SCSS |
| `static/` | **原样复制**，一个字节都不改 | 要保持原样的文件，如 robots.txt、字体 |
| `resources/` | Hugo 的**缓存输出**（`_gen/`），不是你的文件 | 不用管，删了只会让下次构建变慢 |

> 注意：`static/` 下的同名文件会直接覆盖 `public/` 根目录路径，例如 `static/favicon.ico` 会和 Hugo Pipes 生成的 favicon 冲突，图标类文件统一放 `assets/`。

---

## 10. 推荐工作流

1. `hugo server -D` 开启本地预览
2. 用编辑器写文章（`content/posts/`）
3. 浏览器实时查看效果
4. 写完后把 `draft = false`
5. 执行 `hugo` 构建
6. 推送到 GitHub，由平台自动部署

---

**提示：**  
遇到问题时，优先查看主题官方文档（尤其是 PaperMod 的 Wiki）和 [Hugo 官方文档](https://gohugo.io/documentation/)。

有新的常用场景可以随时补充到这个 README 里。
```

把上面内容直接复制保存为项目根目录的 `README.md` 即可。