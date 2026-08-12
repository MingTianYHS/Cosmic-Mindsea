# Cosmic Mindsea Knowledge System

Cosmic Mindsea Knowledge System 是一个可部署到 Obsidian Vault 的 Agent 驱动知识库管理工具发行版。它把以下三层作为同一个可迭代系统进行版本控制：

1. `.agents/skills/`：技能、共享规则、Python 工具和集成代码；
2. `_CLAUDE.md`：Agent 在 Cosmic Mindsea Vault 中工作的治理规则；
3. `.vault-config.json`：Vault 扫描和运行配置。

本仓库**不包含真实知识库内容**。`Knowledge/`、`Ideas/`、`Projects/`、`Research/`、日志、Obsidian 状态和运行缓存均被排除。

## 项目状态

- Skill 体系来源：[eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain)
- 本地安装版本：`0.14.0`
- 当前发行形态：Agent Skills 安装/运行树，加 Cosmic Mindsea 实例治理与配置
- 主要平台：Windows、PowerShell、Obsidian、Codex/Claude 类 Agent

> 重要：本仓库保存的是当前真实运行工具的干净发行副本。很多命令 `SKILL.md` 是上游构建生成的 wrapper。若要进行大规模命令开发或向上游贡献，请同时使用完整上游源码中的 `commands/`、`adapters/`、`tests/` 和 CI，而不要只手工修改生成文件。

## 目录

```text
.
├─ .agents/
│  └─ skills/
│     ├─ obsidian-core/       # 公共规则、脚本、依赖定义和集成
│     └─ <command skills>/    # 45 个命令 Skill
├─ docs/
│  ├─ architecture.md
│  ├─ privacy.md
│  └─ upstream.md
├─ _CLAUDE.md                 # Cosmic Mindsea 治理规则
├─ .vault-config.json         # Vault 排除配置
├─ install.ps1                # Windows 安装/更新入口
├─ verify.ps1                 # 上传或发布前自检
├─ LICENSE
└─ NOTICE.md
```

## 能做什么

Skills 覆盖以下能力：

- 捕获想法、人物、任务、项目和决策；
- 创建每日笔记、项目记录、周/月回顾；
- 搜索、索引、健康检查、矛盾发现和知识综合；
- 研究、YouTube、Podcast、NotebookLM 和 X 内容处理；
- 将代码架构、开发过程和研究结果写入 Vault；
- 按 AI-first 规则保存来源、时间、置信度和 wikilink。

Skill 不会自己作为后台服务自动运行。Codex、Claude 或兼容 Agent 在处理用户请求时读取对应的 `SKILL.md`，再调用公共脚本或按规则操作 Vault。

## 安装

### 前提

- Windows PowerShell 5.1 或 PowerShell 7；
- 一个现有或空的 Obsidian Vault 目录；
- 若使用 Python 研究/健康工具，需要 Python 3.10+ 和项目文档要求的 `uv`；
- 联网研究功能可能需要相应 Provider 的 API Key，但 Key 不应存储在本仓库。

### 先验证发行包

```powershell
Set-Location '<仓库目录>'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\verify.ps1'
```

### 预览安装，不修改目标 Vault

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\install.ps1' `
  -VaultPath 'D:\Your Vault' -WhatIf
```

### 安装或更新

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\install.ps1' `
  -VaultPath 'D:\Your Vault'
```

这里的 `-ExecutionPolicy Bypass` 只作用于这一个新 PowerShell 进程，不修改用户或系统的永久执行策略。

安装器只部署：

```text
.agents/skills/
_CLAUDE.md
.vault-config.json
```

如果目标中已有这些路径，安装器会先备份到：

```text
<Vault>\.codex-install-backup\YYYYMMDDTHHMMSSZ\
```

安装器不会复制或修改 `Knowledge/`、`Ideas/`、`Projects/` 等知识目录。

## 开发原则

### 可以在本仓库维护

- Cosmic Mindsea 的 `_CLAUDE.md` 和 `.vault-config.json`；
- Windows/Codex 安装和验证体验；
- 通用 Skill 修复和脚本改进；
- 隐私、离线和 Provider 控制；
- 文档、虚构示例和兼容性测试。

### 修改生成 Skill 时要谨慎

多数命令 `SKILL.md` 来自上游 canonical command 和 Agent Skills adapter。直接修改本仓库中的 wrapper 可以改变这个发行版，但升级上游时容易被覆盖。长期改进应优先在完整上游源码中修改：

```text
commands/
references/
scripts/
adapters/
integrations/
tests/
```

详情见 [`docs/upstream.md`](docs/upstream.md)。

## 隐私和网络

普通 Vault 文件操作通常是本地的，但研究、YouTube、Podcast、NotebookLM、X、链接 triage 等功能可能访问外部服务并发送查询、来源或有限的笔记上下文。启用前请阅读 [`docs/privacy.md`](docs/privacy.md)。

永远不要提交：

- `.env`、API Key、Token 或账号凭据；
- 真实私人笔记、日志和测试 fixture；
- `.venv`、`.deps`、缓存或 Obsidian 运行状态；
- 从真实 Vault 复制的截图或示例数据。

## 验证范围

`verify.ps1` 检查：

- 必需的项目文件；
- `.vault-config.json` JSON 有效性；
- 46 个 Skill 目录及其 `SKILL.md`；
- 不存在 `.venv`、`.deps`、`__pycache__` 和 `.pyc`；
- 常见真实密钥格式和私钥头；
- 若本机有 Python，则检查项目 Python 文件语法。

这不等于完整上游测试。完整功能开发仍应在上游完整源码仓库中运行其 Ruff、pytest、构建和多平台 CI。

## 许可证与来源

本仓库包含并改编自 `obsidian-second-brain` 的 MIT 许可内容。请参阅：

- [`LICENSE`](LICENSE)
- [`NOTICE.md`](NOTICE.md)
- [`docs/upstream.md`](docs/upstream.md)

Cosmic Mindsea 的实例治理和配置与上游 Skill 发行内容一起分发，但这不改变上游代码的原始版权和许可证要求。
