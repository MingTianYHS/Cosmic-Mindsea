# Cosmic Mindsea Agent Contract

## 目标

本仓库只维护 Codex/Agent Skills 方向的 Obsidian 知识库管理工具发行版。默认适配器是 `adapters/agent-skills/adapter.sh`；不要在没有明确设计与验证的情况下重新引入 Claude、Gemini、OpenCode、Hermes、Pi 或弃用的 `codex-cli` 适配器。

## 源码与生成产物所有权

- `commands/`、`references/`、`scripts/` 是规范源码。
- `adapters/lib.sh` 和 `adapters/agent-skills/adapter.sh` 是构建逻辑。
- `.agents/skills/` 是已提交、可直接安装的生成产物。
- `dist/` 是本地重建输出，不提交。

需要改变 Skill 行为时，优先修改规范源码；然后运行：

```bash
bash scripts/build.sh --platform agent-skills
```

将 `dist/agent-skills/skills/` 的完整结果同步到 `.agents/skills/`，再运行测试和树比较。不要让生成产物与源码发生未经说明的手工漂移。

## 必须验证

修改后至少运行：

```powershell
python -m unittest discover -s tests -p 'test_*.py' -v
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1 `
  -ProjectRoot . `
  -CompareGenerated .\dist\agent-skills\skills
```

如修改安装器，必须使用临时 Vault 验证：普通笔记和无关 Skill 保留，同名受管 Skill 在替换前已备份，且没有写入临时 Vault 外部。

## 隐私与提交边界

禁止提交：

- `.env`、API Key、Token、认证文件、私钥；
- 真实 Vault 的笔记、附件、用户实例规则或 `_CLAUDE.md`；
- `.obsidian/`、`.cache/`、`.runtime/`、`.venv/`；
- `.codex-install-backup/`、日志、Python 字节码和本地依赖；
- 任何无法证明来自固定上游源码或本仓库开发过程的私人内容。

`.env.example` 只能包含空占位符和公开说明。安装器不得设置默认真实 Vault 路径，不得在没有显式 `-VaultPath` 的情况下写入任何 Vault。

## 改动原则

- 保留 MIT `LICENSE` 和 `NOTICE.md` 中的上游归属。
- 采用最小、可回滚的改动；不要进行无关重构或平台扩张。
- 发布前检查完整文件清单、敏感信息扫描、测试、重新构建一致性和远端树。
- 不通过删除、跳过或弱化测试制造成功结果。
