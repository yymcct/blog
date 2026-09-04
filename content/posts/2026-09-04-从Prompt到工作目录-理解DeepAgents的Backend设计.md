+++
title = '从Prompt到工作目录：理解DeepAgents的Backend设计'
slug = 'deepagents-backend'
date = 2026-09-04T11:24:41+08:00
description = '从 Backend 抽象理解 Deep Agents 如何用虚拟文件系统管理工作区、临时状态和长期记忆。'
+++

# 从Prompt到工作目录：理解DeepAgents的Backend设计

很多人刚开始写 agent，第一反应通常是这几个问题：

prompt 怎么写？工具怎么接？memory 怎么做？

我一开始也是这么想的。因为 agent 看起来最核心的东西就是模型、提示词、工具调用。只要 prompt 写清楚，再给它几个工具，比如搜索、查数据库、写文件、发消息，似乎就能跑起来。

但真的做一段时间之后，会遇到一个更朴素的问题：

agent 在工作过程中会产生很多东西。临时草稿、搜索结果、分析计划、用户偏好、长期记忆、最终报告。它们应该放在哪里？哪些只在当前对话里有效？哪些需要长期保存？哪些可以被多个任务复用？哪些绝对不能让 agent 修改？

这个问题一开始不明显。demo 阶段，所有东西都塞进上下文也能凑合。可是稍微做复杂一点，问题就来了。

上下文会越来越长。  
中间结果容易丢。  
记忆变成一坨摘要。  
工具返回的内容不知道该怎么沉淀。  
用户下次再来时，agent 好像“记得”，但记得很模糊。

这时候再回头看 Claude Code 的一些设计，就会觉得挺有意思。

它不是只提供一个抽象的 memory API，而是很直接地把一部分记忆落到了文件上。比如项目级记忆放在：`./CLAUDE.md`, 用户级记忆放在：`~/.claude/CLAUDE.md`。

这些 memory 文件会在 Claude Code 启动时加载进上下文。Claude Code 还会从当前工作目录往上递归查找 `CLAUDE.md`，所以在一个大仓库的子目录里工作时，它可以同时读到上层项目规则和当前子模块规则。

更有意思的是，`CLAUDE.md` 还支持用 `@path/to/import` 导入其他文件。比如你可以在里面引用 README、package.json、团队 Git 规范，甚至引用用户主目录里的个人偏好文件。

显然Claude Code 用 Markdown 文件解决了一部分项目记忆和用户记忆的问题。

当我们自己开发 agent 时，可以受到启发：agent 的记忆不一定非得长成一个神秘的 memory 系统。很多时候，最自然的方式就是文件。

像程序员读 README 一样，agent 也可以读一个项目说明。  
像我们写开发笔记一样，agent 也可以把阶段性判断写下来。  
像团队维护规范文档一样，agent 也可以从固定路径读取规则。

这个说法可能不够“高级”，但我慢慢觉得，它反而更接近真实开发。

问题是，如果我们也想做类似 Claude Code 这种效果，该怎么设计？

总不能所有东西都塞进一个 `memory.md`。也不能让 agent 想写哪就写哪。更不能在生产环境里直接给它整个磁盘权限。

这时候，Deep Agents 的 Backend 抽象就很值得看了。

## Backend 是什么

Deep Agents 里的 Backend 更接近“文件系统后端” 准确说是 “虚拟文件系统后端”。

Deep Agents 会给 agent 暴露一组文件系统工具，比如：

```
ls
read_file
write_file
edit_file
grep
glob
```

agent 可以像操作文件一样工作：

```
read_file("/workspace/plan.md")
write_file("/memories/user.md", "用户偏好...")
grep("报警", "/research/")
```

关键在于，agent 看到的是路径，但路径背后到底存在哪里，由 Backend 决定。

比如：

```
StateBackend        存在当前 thread 的状态里
StoreBackend        存在跨 thread 的长期存储里
FilesystemBackend   存到真实本地磁盘
ContextHubBackend   存到 LangSmith Context Hub
CompositeBackend    按路径分发到不同 backend
```

所以Backend 就是给 agent 规划工作目录，并决定每个目录背后的真实存储位置。

agent 只管在 `/workspace/plan.md` 里写计划，在 `/memories/user.md` 里读用户偏好。至于这些文件最终是存在内存、数据库、本地磁盘还是云端仓库，它不用关心。

## 默认情况下，agent 有一个临时工作目录

如果不配置 Backend，Deep Agents 默认使用 `StateBackend`。

可以粗略理解为：agent 看到的虚拟文件系统根目录 `/`，默认存在当前 thread 的状态里。

比如 agent 写：

```
/plan.md
/workspace/draft.md
/large_tool_results/search-result.md
```

这些文件会跟着当前 thread 保存。当前对话里，下一轮还可以读到。但换一个 thread，它们不会自动共享。

这就像给 agent 一张当前任务专用的工作目录。

它可以在里面放草稿、计划、中间结果。任务还在，这些东西就还在。任务结束了，它们也不一定需要变成长期记忆。

这点挺重要。因为很多 agent 的“记忆混乱”，其实不是因为 memory 能力不够，而是因为没有区分：

```
临时工作内容
长期用户偏好
项目知识
最终产物
```

我们工作时不会把这些东西混在一个地方。我们会有草稿纸、项目目录、归档文件夹、规范文档。agent 也需要类似的结构。

## CompositeBackend 像给目录做挂载

真正让我觉得 Backend 设计有意思的，是 `CompositeBackend`。

它可以把不同路径映射到不同 backend。

比如：

```
/               -> StateBackend
/memories/      -> StoreBackend
/project/       -> FilesystemBackend
/policies/      -> StoreBackend，只读
```

agent 看到的仍然是一个统一的文件系统：

```
/workspace/plan.md
/memories/user-preferences.md
/project/src/app.py
/policies/security.md
```

但背后的真实落点不同。

这个东西有点像linux里的 mount。程序访问 `/mnt/data`，不需要知道背后是本地磁盘、网络盘，还是别的存储。agent 访问 `/memories/user-preferences.md`，也不需要知道背后是 LangGraph Store、数据库，还是别的系统。

工具只负责读写路径。  
Backend 负责决定路径落到哪里。  
CompositeBackend 负责把不同目录接到不同地方。

这样一来，路径就不只是路径了，它开始带有业务含义。

```
/scratch/       临时想法
/workspace/     当前任务
/research/      资料沉淀
/memories/      长期记忆
/policies/      规则和约束
/artifacts/     最终产物
```

我觉得这比单独设计十几个 `save_xxx()`、`load_xxx()` 工具要清爽很多。

## 一个更像现场的例子：安防值守 Agent

举个具体点的例子。

假设我们要做一个安防值守 agent，帮园区或工厂处理摄像头、传感器和告警系统的信息。

demo 阶段很容易做：

```
接入摄像头告警工具
接入设备状态查询工具
接入通知工具
写一个 prompt：你是安防值守助手
```

这能演示，但离现场还差一截。

真实场景里，麻烦很快就会冒出来：一个客户可能有多个园区，一个园区有很多摄像头，每天会产生很多告警。告警还不一定准，树影、反光、施工人员路过都可能造成误报；夜间画面差、摄像头角度不对，又可能导致漏报。

客户最关心的也不是 agent 能不能说一句“已判断无风险”。他们会继续问：

```
这次告警属于哪个客户、哪个园区、哪个摄像头？
agent 当时看到了什么？
它依据哪条规则判断？
有没有人工确认？
如果后面出事，能不能追溯？
```

这时候，如果所有东西都塞在上下文里，很快就乱了。

更稳一点的做法，是给 agent 规划清楚的工作目录：

```
/workspace/current-event/        当前事件处理过程
/tenants/{tenant_id}/            客户隔离
/tenants/{tenant_id}/sites/{site_id}/
/tenants/{tenant_id}/sites/{site_id}/devices/{device_id}/
/tenants/{tenant_id}/sites/{site_id}/events/{date}/{event_id}/
/policies/                       处置规则，只读
/audit/                          审计记录
```

处理一次告警时，业务系统先生成明确的 `tenant_id`、`site_id`、`device_id`、`event_id`，再把本次事件目录交给 agent。

事件内部可以简单分几类文件：

```
raw-alert.json        原始告警
timeline.md           时间线
investigation.md      排查过程
evidence.md           证据摘要
human-review.md       人工确认
final-report.md       最终报告
action-log.md         操作记录
```

Markdown 用来写过程、判断和报告；原始告警、检测结果、截图、指标这些，继续用 JSON、图片或表格保存。不是所有东西都要变成 Markdown。

Backend 在这里的作用，是把这些目录背后的真实落点分开：

```
/workspace/   当前 thread 的 StateBackend
/tenants/     按 tenant_id 隔离的 StoreBackend
/policies/    只读规则库
/audit/       可追溯的持久记录
```

它可以在 `/workspace/current-event/` 里分析当前告警，读取 `/policies/` 里的规则，查看设备历史，写出最终报告，再把结果归档到对应客户、园区和事件目录下。

## Markdown 很自然，但不是唯一答案

很多 agent 的工作记忆适合用 Markdown。

原因很简单：

```
人能读
模型也能读
容易编辑
容易 diff
适合写计划、总结、规则、报告
```

所以 Claude Code 用 `CLAUDE.md` 这类文件并不奇怪。对 coding agent 来说，Markdown 是一个很舒服的中间层。

但 Backend 的重点不在于“底层必须是 Markdown”。

更准确地说，是 agent 的认知界面可以表现为文件系统。

底层可以是数据库，可以是对象存储，可以是 LangGraph Store，也可以是真实磁盘。agent 不一定需要知道。

它只需要知道：

```
/memories/ 是长期记忆
/workspace/ 是当前任务
/policies/ 是规则
/artifacts/ 是最终产物
```

这就够了。

某种意义上，这是“一切皆文件”的思想在 agent 开发里的一个变体。不是说真实世界里所有东西都必须变成文件，而是说我们可以把很多信息，用文件路径的方式暴露给 agent。

这种方式对程序员很友好。因为目录结构本来就是我们组织复杂项目的方式。

## 安全边界不能只靠 prompt

这里还有一个现实问题：一旦 agent 能读写文件，就不能只靠 prompt 管它。

比如你不能只写：

```
请不要修改安全规则。
```

更稳妥的做法是从系统层面限制：

```
/policies/ 只读
/project/ 限制在指定 root_dir
FilesystemBackend 开启 virtual_mode=True
多用户数据用 namespace 隔离
高风险操作走人工确认
生产环境尽量不要直接用 LocalShellBackend
```

这也是 Backend 重要的地方。

它不只是“数据存哪里”的问题，也是在帮我们定义边界：哪些地方能写，哪些地方只能读，哪些内容跨任务复用，哪些内容只属于当前 thread，哪些能力必须放进沙箱。

很多 agent 产品做不稳，不是模型不够聪明，而是这些边界没有设计清楚。

## 从 prompt 到工作目录

所以回到标题：从 Prompt 到工作目录。

以前我们可能主要想：

```
prompt 怎么写？
工具怎么接？
memory 怎么做？
```

现在可以多想一步：

```
agent 的工作目录应该怎么规划？
每个目录背后的数据落点是什么？
```

因为 agent 不是只在“回答”用户。它也在工作。工作就会产生材料、草稿、判断、记录和产物。

如果这些东西没有地方放，agent 就只能依赖上下文和一坨 memory。短任务还行，长任务就会乱。

Backend 给了我们一个更朴素的切入点：

先别急着把 agent 变得多智能。  
先给它一个根目录。  
再给它几个文件夹。  
哪些临时，哪些长期，哪些只读，哪些可写，先分清楚。

