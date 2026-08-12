# Cosmic Mindsea

面向 **OpenAI Codex / Agent Skills** 的 Obsidian 知识库管理技能发行版。

本仓库基于 [eugeniughelbur/obsidian-second-brain](https://github.com/eugeniughelbur/obsidian-second-brain) 的固定源码快照进行适配，保留可维护源码，并提交可直接安装的 `.agents/skills/` 生成产物。当前发行版包含：

- **45 个命令 Skill**：捕获、检索、项目、任务、复盘、研究、知识库健康等；
- **1 个 `obsidian-core` Skill**：共享规则、Python 工具和运行资产；
- 共 **46 个 Skill 目录**。

> 本仓库是工具源码和技能发行版，不是某个用户的 Obsidian Vault。仓库不包含私人笔记、Obsidian 状态、运行缓存、日志、备份或密钥，也不会在克隆或验证时自动写入任何真实 Vault。

## 快速使用

### 1. 克隆仓库

```powershell
git clone https://github.com/MingTianYHS/Cosmic-Mindsea.git
Set-Location .\Cosmic-Mindsea
```

### 2. 先预览安装范围

请将示例路径改成你自己的 Vault 路径：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 `
  -VaultPath 'D:\Path\To\Your Vault' `
  -WhatIf
```

预览确认后再去掉 `-WhatIf`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 `
  -VaultPath 'D:\Path\To\Your Vault'
```

安装器只复制仓库中的 `.agents/skills/`：

- 不会删除 Vault 内的普通笔记；
- 不会删除其他自定义 Skill；
- 若目标中存在同名的本仓库受管 Skill，会先备份到：
  `.agents/.codex-install-backup/<UTC 时间戳>/`；
- 没有默认 Vault 路径，必须由使用者明确传入 `-VaultPath`。

建议从 Vault 根目录启动 Codex，让工作区的 `.agents/skills/<name>/SKILL.md` 可以被发现，并让相对的共享资产路径稳定解析。

## 验证

需要 Python 3.10+：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1 `
  -ProjectRoot .
```

验证器会只读检查：

- Skill 目录与 `SKILL.md`；
- frontmatter `name` 与目录名是否一致；
- `obsidian-core` 的必要运行资产；
- 私有 Vault 根目录、运行目录和弃用/外部平台适配器是否混入；
- 常见私钥和 Token 格式。

运行自动化测试：

```powershell
python -m unittest discover -s tests -p 'test_*.py' -v
```

## 从源码重新生成 Skills

仓库采用“源码 + 生成产物”的混合结构：

- `commands/`、`references/`、`scripts/`：规范源码；
- `adapters/lib.sh`、`adapters/agent-skills/adapter.sh`：Agent Skills 构建器；
- `.agents/skills/`：供 Codex 直接使用的生成产物。

在 Git Bash、WSL 或其他 Bash 环境中运行：

```bash
bash scripts/build.sh --platform agent-skills
```

输出位于：

```text
dist/agent-skills/skills/
```

开发者应修改源码后重新构建，再用验证器比较生成结果：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1 `
  -ProjectRoot . `
  -CompareGenerated .\dist\agent-skills\skills
```

不要只手工修改 `.agents/skills/` 而不更新对应源码，否则后续重建会覆盖变更。

## 可选配置与依赖

多数知识库管理 Skills 不需要第三方 API Key。研究类功能会按使用场景选择性读取 `.env.example` 中列出的变量，例如 xAI、Perplexity、Gemini、Tavily、Brave 或 YouTube API。空值只是占位符，不是密钥。

如果需要 Python 研究工具依赖，可使用上游保留的项目元数据：

```powershell
uv sync
```

然后将 `.env.example` 复制到你自行管理的私有配置位置并填写所需值。**不要提交 `.env`。** 使用云端模型或嵌入服务时，笔记内容可能被发送给该服务；请先评估隐私范围。未配置可选 API 时，相关功能可能降级或不可用，但这不影响仓库结构验证。

## 隐私与安全边界

本仓库明确排除：

- `.env`、Token、API Key、认证文件和私钥；
- `.obsidian/`、`.cache/`、`.runtime/`、`.venv/`；
- 安装备份、日志和生成缓存；
- 用户的 `Bases/`、`Ideas/`、`Knowledge/`、`Learning/`、`Logs/`、`Projects/`、`Research/` 等 Vault 内容目录；
- 用户实例专属 `_CLAUDE.md` 和其他私人规则文件。

安装脚本具有写入用户指定 Vault 的能力，所以请始终先运行 `-WhatIf`、确认绝对路径并保留备份。仓库自身不会自动执行安装。

## 来源与许可证

- 上游项目：[`eugeniughelbur/obsidian-second-brain`](https://github.com/eugeniughelbur/obsidian-second-brain)
- 固定上游提交：`4d5b6738d79cca0b222e7874798c039a0dfd53b3`
- 原作者：Eugeniu Ghelbur
- 许可证：MIT

详见 [`NOTICE.md`](NOTICE.md) 和 [`LICENSE`](LICENSE)。
