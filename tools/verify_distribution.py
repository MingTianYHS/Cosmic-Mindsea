#!/usr/bin/env python3
"""Verify a Cosmic Mindsea source distribution or installed skills tree."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path


FORBIDDEN_ROOTS = {
    ".cache",
    ".claude-plugin",
    ".codex-install-backup",
    ".obsidian",
    ".runtime",
    ".venv",
    "Bases",
    "Ideas",
    "Knowledge",
    "Learning",
    "Logs",
    "Projects",
    "Research",
}
FORBIDDEN_ADAPTERS = {"claude-code", "codex-cli", "gemini-cli", "hermes", "opencode", "pi"}
FORBIDDEN_FILENAMES = {".env", "_CLAUDE.md"}
IGNORED_DIRECTORY_NAMES = {".git", ".pytest_cache", ".ruff_cache", "__pycache__", "dist"}
IGNORED_FILE_SUFFIXES = {".pyc", ".pyo"}
PRIVATE_VAULT_DRIVE = b"D:"
PRIVATE_VAULT_NAME = b"Cosmic Mindsea"
SECRET_PATTERNS = (
    ("OpenAI-style API key", re.compile(rb"\bsk-[A-Za-z0-9_-]{20,}\b")),
    ("GitHub token", re.compile(rb"\bgh(?:p|o|u|s|r)_[A-Za-z0-9]{20,}\b")),
    ("AWS access key", re.compile(rb"\bAKIA[0-9A-Z]{16}\b")),
    ("private key", re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
)


def parse_frontmatter(path: Path) -> dict[str, str]:
    """Parse simple top-level YAML scalar values from a SKILL.md frontmatter block."""
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}

    values: dict[str, str] = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        if line[:1].isspace() or ":" not in line:
            continue
        key, value = line.split(":", 1)
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        values[key.strip()] = value
    return values


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _file_map(root: Path) -> dict[str, str]:
    return {
        path.relative_to(root).as_posix(): _sha256(path)
        for path in sorted(root.rglob("*"))
        if path.is_file()
    }


def _contains_private_vault_path(data: bytes) -> bool:
    windows_path = PRIVATE_VAULT_DRIVE + b"\\" + PRIVATE_VAULT_NAME
    posix_path = PRIVATE_VAULT_DRIVE + b"/" + PRIVATE_VAULT_NAME
    folded = data.lower()
    return windows_path.lower() in folded or posix_path.lower() in folded


def compare_trees(left: Path, right: Path) -> list[str]:
    findings: list[str] = []
    if not left.is_dir():
        return [f"missing comparison tree: {left}"]
    if not right.is_dir():
        return [f"missing comparison tree: {right}"]

    left_files = _file_map(left)
    right_files = _file_map(right)
    for relative in sorted(left_files.keys() - right_files.keys()):
        findings.append(f"only in committed skills: {relative}")
    for relative in sorted(right_files.keys() - left_files.keys()):
        findings.append(f"only in generated skills: {relative}")
    for relative in sorted(left_files.keys() & right_files.keys()):
        if left_files[relative] != right_files[relative]:
            findings.append(f"content mismatch: {relative}")
    return findings


def _resolve_skills_root(root: Path) -> tuple[Path | None, bool]:
    repository_skills = root / ".agents" / "skills"
    if repository_skills.is_dir():
        return repository_skills, True
    installed_skills = root / "skills"
    if installed_skills.is_dir():
        return installed_skills, False
    if root.is_dir() and (root / "obsidian-core" / "SKILL.md").is_file():
        return root, False
    return None, False


def verify_distribution(root: Path, compare_generated: Path | None = None) -> list[str]:
    root = root.resolve()
    findings: list[str] = []
    skills_root, repository_mode = _resolve_skills_root(root)
    if skills_root is None:
        return [f"could not locate skills under: {root}"]

    skill_dirs = sorted(path for path in skills_root.iterdir() if path.is_dir())
    if not skill_dirs:
        findings.append(f"no skill directories found: {skills_root}")

    for skill_dir in skill_dirs:
        skill_file = skill_dir / "SKILL.md"
        if not skill_file.is_file():
            findings.append(f"missing SKILL.md: {skill_dir.relative_to(root)}")
            continue
        name = parse_frontmatter(skill_file).get("name")
        if name != skill_dir.name:
            findings.append(
                f"frontmatter name mismatch: {skill_file.relative_to(root)} "
                f"declares {name!r}, expected {skill_dir.name!r}"
            )

    core = skills_root / "obsidian-core"
    for relative in (
        "SKILL.md",
        "pyproject.toml",
        "references/ai-first-rules.md",
        "references/vault-schema.md",
        "scripts/build.sh",
        "scripts/vault_health.py",
        "scripts/research/research.py",
    ):
        if not (core / relative).is_file():
            findings.append(f"obsidian-core runtime asset missing: {relative}")

    if repository_mode:
        actual_roots = {path.name for path in root.iterdir()}
        for name in sorted(FORBIDDEN_ROOTS & actual_roots):
            findings.append(f"forbidden repository root present: {name}")
        for name in sorted(FORBIDDEN_FILENAMES):
            if (root / name).exists():
                findings.append(f"forbidden private/config file present: {name}")
        adapter_root = root / "adapters"
        for name in sorted(FORBIDDEN_ADAPTERS):
            if (adapter_root / name).exists():
                findings.append(f"foreign or deprecated adapter present: adapters/{name}")

    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if any(part in IGNORED_DIRECTORY_NAMES for part in relative.parts):
            continue
        if path.suffix.lower() in IGNORED_FILE_SUFFIXES:
            continue
        if not path.is_file() or path.stat().st_size > 5 * 1024 * 1024:
            continue
        data = path.read_bytes()
        for label, pattern in SECRET_PATTERNS:
            if pattern.search(data):
                findings.append(f"possible {label}: {relative.as_posix()}")
        if _contains_private_vault_path(data):
            findings.append(f"private Vault path literal present: {relative.as_posix()}")

    if compare_generated is not None:
        findings.extend(compare_trees(skills_root, compare_generated.resolve()))
    return findings


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--compare-generated", type=Path)
    args = parser.parse_args(argv)

    findings = verify_distribution(args.root, args.compare_generated)
    if findings:
        print(f"Verification failed with {len(findings)} finding(s):", file=sys.stderr)
        for finding in findings:
            print(f"- {finding}", file=sys.stderr)
        return 1

    skills_root, _ = _resolve_skills_root(args.root.resolve())
    assert skills_root is not None
    skill_count = sum(1 for path in skills_root.iterdir() if path.is_dir())
    file_count = sum(1 for path in skills_root.rglob("*") if path.is_file())
    print(f"Verification passed: {skill_count} skills, {file_count} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
