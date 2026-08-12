# Cosmic Mindsea Codex Adaptation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `MingTianYHS/Cosmic-Mindsea` with a verified Codex-focused hybrid distribution derived from `eugeniughelbur/obsidian-second-brain`, preserving source files and ready-to-install `.agents/skills` output.

**Architecture:** Work only in an isolated directory under the current Codex workspace. Pin the upstream commit, retain the platform-neutral source and recommended `agent-skills` adapter, generate `.agents/skills`, add Windows install/verification wrappers and provenance documentation, then publish a normal child commit of the current target `main` after creating a backup branch.

**Tech Stack:** Git, Bash/Git Bash, PowerShell 5.1+, Python 3.10+, uv project metadata, GitHub.

## Global Constraints

- Do not read from, write to, or install into `<PRIVATE_VAULT_PATH>` during this task.
- Upstream source commit is pinned to `4d5b6738d79cca0b222e7874798c039a0dfd53b3` unless a fresh pre-publication check proves `main` changed and the user explicitly approves a newer pin.
- Use `adapters/agent-skills/adapter.sh`; exclude deprecated `adapters/codex-cli/`.
- Preserve the upstream MIT license and identify the adaptation and pinned source in `NOTICE.md`.
- Never publish `.env`, credentials, private Vault content, caches, virtual environments, installed dependencies, or runtime state.
- Create `backup/pre-codex-adaptation-2026-08-13` from the target's pre-replacement `main` before updating `main`.
- Update `main` by fast-forwarding to an ordinary child commit; do not force-push or rewrite history.
- Stage explicit paths only; never use `git add .`, `git add -A`, or `git add --all`.
- Claim completion only after fresh local and remote verification.

---

## File Map

- `.agents/skills/`: generated, directly installable Codex Agent Skills.
- `commands/`: canonical command instruction sources.
- `references/`: shared reference documents used by generated skills.
- `scripts/`: Python and shell runtime/build utilities.
- `adapters/lib.sh`: shared adapter functions required by the Agent Skills build.
- `adapters/agent-skills/adapter.sh`: recommended Agent Skills generator.
- `scripts/build.sh`: selected build dispatcher copied from upstream because it invokes the adapter.
- `AGENTS.md`: Codex repository operating contract and generated-output ownership rules.
- `README.md`: Chinese-first installation, development, privacy, and provenance guide.
- `install.ps1`: safe installer that copies only `.agents/skills` into a user-supplied Vault.
- `verify.ps1`: read-only repository or installed-tree structural verifier.
- `tools/verify_distribution.py`: deterministic cross-platform verifier used by PowerShell and CI-style local checks.
- `tests/test_distribution.py`: tests for generated tree, installer isolation, source/generated parity, and exclusions.
- `LICENSE`: upstream MIT license.
- `NOTICE.md`: upstream repository, author, license, pinned commit, and adaptation declaration.
- `.env.example`: placeholder-only provider variables from upstream, reviewed for secrets.
- `.gitignore`, `.gitattributes`: privacy and line-ending rules.
- `pyproject.toml`, `uv.lock`: upstream dependency metadata retained for source iteration.
- `docs/superpowers/specs/2026-08-13-cosmic-mindsea-codex-adaptation-design.md`: approved design.
- `docs/superpowers/plans/2026-08-13-cosmic-mindsea-codex-adaptation.md`: this implementation plan.

### Task 1: Prepare pinned isolated checkouts

**Files:**
- Create directory: `work/upstream/`
- Create directory: `work/target/`
- Create: `work/evidence/preflight.txt`

**Interfaces:**
- Consumes: upstream and target GitHub URLs plus pinned SHAs from the approved spec.
- Produces: clean local checkouts and a recorded preflight state used by every later task.

- [ ] **Step 1: Clone the source and target repositories into isolated directories**

Run:

```powershell
git clone https://github.com/eugeniughelbur/obsidian-second-brain.git work/upstream
git clone https://github.com/MingTianYHS/Cosmic-Mindsea.git work/target
```

Expected: both commands exit 0; neither destination resolves under `<PRIVATE_VAULT_PATH>`.

- [ ] **Step 2: Pin and record repository state**

Run:

```powershell
git -C work/upstream checkout --detach 4d5b6738d79cca0b222e7874798c039a0dfd53b3
git -C work/target checkout main
git -C work/upstream rev-parse HEAD
git -C work/target rev-parse HEAD
git -C work/target status --short
```

Expected: upstream HEAD is the pinned SHA; target HEAD is the freshly fetched remote `main`; target status is empty.

- [ ] **Step 3: Record the immutable preflight evidence**

Write `work/evidence/preflight.txt` with repository URLs, current SHAs, UTC timestamp, and `git status --short --branch` outputs.

### Task 2: Build the recommended Agent Skills distribution

**Files:**
- Generate: `work/upstream/dist/agent-skills/skills/**`
- Create: `work/evidence/build.txt`

**Interfaces:**
- Consumes: pinned upstream checkout and `scripts/build.sh --platform agent-skills`.
- Produces: canonical generated tree copied by Task 3.

- [ ] **Step 1: Run the upstream build**

Run from `work/upstream`:

```bash
bash scripts/build.sh --platform agent-skills
```

Expected: exit 0 and `dist/agent-skills/skills/obsidian-core/SKILL.md` exists.

- [ ] **Step 2: Inspect generated skill inventory**

Run:

```powershell
Get-ChildItem work/upstream/dist/agent-skills/skills -Directory | Sort-Object Name | Select-Object -ExpandProperty Name
```

Expected: one shared `obsidian-core` plus command Skill directories, each with `SKILL.md`.

- [ ] **Step 3: Save complete build output and generated file hashes**

Record build command output, exit code, generated file count, and SHA-256 manifest in `work/evidence/build.txt` and `work/evidence/generated.sha256`.

### Task 3: Assemble the hybrid repository tree

**Files:**
- Replace target working tree paths explicitly.
- Create/modify all files listed in the File Map.

**Interfaces:**
- Consumes: pinned upstream source and generated Agent Skills tree.
- Produces: complete Codex-focused repository working tree ready for tests.

- [ ] **Step 1: Remove the old tracked target tree from the local feature branch**

Create branch `codex-agent-skills-adaptation-2026-08-13`, list the exact tracked paths using `git ls-files`, and remove only those paths with `git rm -- <explicit paths>` or safe repository-local deletion followed by explicit staging. Verify the resolved target root before recursive removal.

- [ ] **Step 2: Copy the selected canonical source paths**

Copy exactly:

```text
commands/
references/
scripts/
adapters/lib.sh
adapters/agent-skills/adapter.sh
pyproject.toml
uv.lock
.env.example
.gitattributes
LICENSE
```

Do not copy any other adapter, `.claude-plugin`, site content, Vault content, caches, or repository history from upstream.

- [ ] **Step 3: Copy generated skills to the direct-install location**

Copy `work/upstream/dist/agent-skills/skills/` to `work/target/.agents/skills/` using a Unicode-safe recursive copy. Generate a fresh SHA-256 manifest of the copied tree and compare it with `work/evidence/generated.sha256`.

- [ ] **Step 4: Add repository-specific documentation and wrappers**

Create Chinese-first `README.md`, Codex `AGENTS.md`, `NOTICE.md`, privacy-focused `.gitignore`, safe `install.ps1`, read-only `verify.ps1`, `tools/verify_distribution.py`, and `tests/test_distribution.py` according to the approved design.

- [ ] **Step 5: Copy the approved spec and implementation plan into the target tree**

Copy both documents from the current workspace `docs/superpowers/` to the matching target paths.

### Task 4: Implement tests and verification first

**Files:**
- Create: `tests/test_distribution.py`
- Create: `tools/verify_distribution.py`
- Create: `verify.ps1`
- Create: `install.ps1`

**Interfaces:**
- `verify_distribution.py --root PATH [--compare-generated PATH]` returns 0 on a valid distribution and nonzero with explicit findings otherwise.
- `verify.ps1 -ProjectRoot PATH [-CompareGenerated PATH]` delegates deterministic checks and remains read-only.
- `install.ps1 -VaultPath PATH [-WhatIf]` copies only `.agents/skills`, preserves unrelated Vault content, and backs up same-name managed skills before replacement.

- [ ] **Step 1: Write failing distribution tests**

Tests must assert:

```python
def test_every_skill_has_matching_frontmatter_name(): ...
def test_obsidian_core_contains_runtime_assets(): ...
def test_deprecated_and_foreign_adapters_are_absent(): ...
def test_private_vault_and_runtime_roots_are_absent(): ...
def test_committed_skills_match_fresh_build(): ...
def test_install_copies_only_managed_skill_directories(): ...
def test_verifier_rejects_mismatched_frontmatter(): ...
```

- [ ] **Step 2: Run tests to verify the wrapper implementation is incomplete**

Run:

```powershell
python -m unittest discover -s tests -p 'test_*.py' -v
```

Expected before implementation: failures caused by missing verifier/installer behavior, not syntax or test collection errors.

- [ ] **Step 3: Implement the minimal verifier and installer**

Implement deterministic path, frontmatter, parity, exclusion, and secret-pattern checks. Installer tests must use a temporary Vault and must never refer to `<PRIVATE_VAULT_PATH>` as an execution target.

- [ ] **Step 4: Run tests to green**

Run:

```powershell
python -m unittest discover -s tests -p 'test_*.py' -v
powershell -NoProfile -ExecutionPolicy Bypass -File .\verify.ps1 -ProjectRoot . -CompareGenerated ..\upstream\dist\agent-skills\skills
```

Expected: all tests pass and verifier exits 0.

### Task 5: Run full local acceptance checks

**Files:**
- Create: `work/evidence/verification.txt`
- Create: `work/evidence/repository.sha256`

**Interfaces:**
- Consumes: assembled repository and generated upstream output.
- Produces: fresh evidence required before commit and push.

- [ ] **Step 1: Rebuild from a clean generated-output directory**

Remove only verified `work/upstream/dist/agent-skills` and rerun the pinned build. Compare the fresh result byte-for-byte with `work/target/.agents/skills`.

- [ ] **Step 2: Test installation into a temporary Vault**

Create a temporary Vault containing an unrelated note and unrelated Skill, run `install.ps1`, then verify:

- generated Skills were installed;
- the unrelated note and Skill remain unchanged;
- no file was written outside the temporary Vault;
- `verify.ps1` succeeds against the installed Skill root mode supported by the verifier.

- [ ] **Step 3: Run source and safety checks**

Run Python AST parsing, selected upstream adapter/build tests if available, line-ending checks, prohibited-root checks, and credential-pattern scans. Save complete command output and exit codes.

- [ ] **Step 4: Review exact Git scope**

Run:

```powershell
git status --short --ignored
git diff --stat
git diff --name-status
git ls-files
```

Expected: only approved hybrid-distribution paths are present; no private or generated runtime artifacts are untracked or ignored unexpectedly.

### Task 6: Commit on a feature branch

**Files:**
- Stage only approved paths listed by `git status --short`.

**Interfaces:**
- Consumes: fully verified target working tree.
- Produces: one ordinary commit whose parent is the pre-replacement target `main`.

- [ ] **Step 1: Re-read remote target main before committing**

Run `git fetch origin main` and compare `origin/main` with the preflight SHA. If changed, stop and reconcile rather than committing against stale state.

- [ ] **Step 2: Stage explicit paths**

Use `git add -- <each approved path>` and `git rm -- <each removed path>` only. Never use broad add commands.

- [ ] **Step 3: Inspect staged content**

Run:

```powershell
git diff --cached --name-status
git diff --cached --stat
git diff --cached --check
```

Expected: complete replacement scope, no whitespace errors, no unrelated files.

- [ ] **Step 4: Commit**

Run:

```powershell
git commit -m "feat: publish Codex-focused Obsidian skills distribution"
```

Expected: one commit on `codex-agent-skills-adaptation-2026-08-13`, parent equal to the preflight target `main`.

### Task 7: Back up and publish the target repository

**Files:**
- Remote branch: `backup/pre-codex-adaptation-2026-08-13`
- Remote branch: `codex-agent-skills-adaptation-2026-08-13`
- Remote branch updated: `main`

**Interfaces:**
- Consumes: verified local commit and unchanged remote `main`.
- Produces: recoverable backup and fast-forwarded public `main`.

- [ ] **Step 1: Create the remote backup branch**

Create `backup/pre-codex-adaptation-2026-08-13` exactly at the pre-replacement `main` SHA. If it already exists, verify it points to that SHA; do not silently move it.

- [ ] **Step 2: Push the feature branch**

Push only `codex-agent-skills-adaptation-2026-08-13` and verify the remote ref equals the local commit.

- [ ] **Step 3: Fast-forward main**

Push `codex-agent-skills-adaptation-2026-08-13:main` without force. Expected: normal fast-forward from the preflight target SHA.

### Task 8: Verify the public GitHub state

**Files:**
- Create: `work/evidence/remote-verification.txt`

**Interfaces:**
- Consumes: published GitHub repository.
- Produces: final evidence that the user-visible repository matches the approved design.

- [ ] **Step 1: Read remote refs and recursive tree**

Verify:

- `main` equals the local release commit;
- backup branch equals the pre-replacement SHA;
- old `_CLAUDE.md` and old `docs/architecture.md`, `docs/privacy.md`, `docs/upstream.md` are absent unless intentionally recreated by this plan;
- `.agents/skills`, source paths, wrappers, license, notice, spec, and plan are present.

- [ ] **Step 2: Fetch critical public files**

Read `README.md`, `AGENTS.md`, `LICENSE`, `NOTICE.md`, `install.ps1`, `verify.ps1`, and representative `SKILL.md` files from GitHub, confirming content and provenance.

- [ ] **Step 3: Compare remote and local commit trees**

Fetch remote `main`, compare tree SHA and file inventory against the verified local release commit, and save output in `work/evidence/remote-verification.txt`.

- [ ] **Step 4: Report actual result and remaining limitations**

Report commit URL, backup branch URL, validation commands and counts, any optional API-dependent behavior not exercised, and explicit confirmation that `<PRIVATE_VAULT_PATH>` was not modified.
