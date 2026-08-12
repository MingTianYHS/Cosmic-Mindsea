from __future__ import annotations

import importlib.util
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERIFY_PATH = ROOT / "tools" / "verify_distribution.py"
INSTALL_PATH = ROOT / "install.ps1"
POWERSHELL = shutil.which("powershell") or shutil.which("pwsh")
BASH = shutil.which("bash")


def load_verifier():
    spec = importlib.util.spec_from_file_location("verify_distribution", VERIFY_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Cannot load verifier: {VERIFY_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class DistributionTests(unittest.TestCase):
    def test_every_skill_has_matching_frontmatter_name(self):
        verifier = load_verifier()
        skills_root = ROOT / ".agents" / "skills"
        skill_dirs = sorted(path for path in skills_root.iterdir() if path.is_dir())

        self.assertGreater(len(skill_dirs), 1)
        for skill_dir in skill_dirs:
            skill_file = skill_dir / "SKILL.md"
            self.assertTrue(skill_file.is_file(), skill_file)
            frontmatter = verifier.parse_frontmatter(skill_file)
            self.assertEqual(skill_dir.name, frontmatter.get("name"), skill_file)

    def test_obsidian_core_contains_runtime_assets(self):
        core = ROOT / ".agents" / "skills" / "obsidian-core"
        required = (
            "SKILL.md",
            "pyproject.toml",
            "references/ai-first-rules.md",
            "references/vault-schema.md",
            "scripts/build.sh",
            "scripts/vault_health.py",
            "scripts/research/research.py",
        )
        for relative in required:
            self.assertTrue((core / relative).is_file(), relative)

    def test_deprecated_and_foreign_adapters_are_absent(self):
        adapter_root = ROOT / "adapters"
        self.assertEqual(
            ["agent-skills"],
            sorted(path.name for path in adapter_root.iterdir() if path.is_dir()),
        )
        self.assertFalse((ROOT / ".claude-plugin").exists())
        self.assertFalse((ROOT / "adapters" / "codex-cli").exists())

    def test_private_vault_and_runtime_roots_are_absent(self):
        forbidden_roots = {
            ".cache",
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
        actual_roots = {path.name for path in ROOT.iterdir()}
        self.assertFalse(forbidden_roots & actual_roots)
        self.assertFalse((ROOT / ".env").exists())
        self.assertFalse((ROOT / "_CLAUDE.md").exists())

    def test_committed_skills_match_fresh_build(self):
        compare = ROOT / "dist" / "agent-skills" / "skills"
        if not compare.is_dir():
            compare = ROOT.parent / "upstream-src" / (
                "obsidian-second-brain-4d5b6738d79cca0b222e7874798c039a0dfd53b3"
            ) / "dist" / "agent-skills" / "skills"
        self.assertTrue(compare.is_dir(), compare)
        verifier = load_verifier()
        self.assertEqual([], verifier.compare_trees(ROOT / ".agents" / "skills", compare))

    @unittest.skipUnless(BASH, "Bash is required for source rebuild verification")
    def test_source_tree_rebuilds_with_only_agent_skills_adapter(self):
        env = os.environ.copy()
        bash_path = Path(BASH)
        env["PATH"] = os.pathsep.join(
            [str(bash_path.parent), str(bash_path.parents[1] / "mingw64" / "bin"), env.get("PATH", "")]
        )
        completed = subprocess.run(
            [BASH, "scripts/build.sh", "--platform", "agent-skills"],
            cwd=ROOT,
            env=env,
            text=True,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
            check=False,
        )

        self.assertEqual(0, completed.returncode, completed.stdout + completed.stderr)
        verifier = load_verifier()
        self.assertEqual(
            [],
            verifier.compare_trees(ROOT / ".agents" / "skills", ROOT / "dist" / "agent-skills" / "skills"),
        )

    @unittest.skipUnless(POWERSHELL, "PowerShell is required for installer verification")
    def test_install_copies_only_managed_skill_directories(self):
        source_skills = ROOT / ".agents" / "skills"
        managed_name = sorted(path.name for path in source_skills.iterdir() if path.is_dir())[0]

        with tempfile.TemporaryDirectory() as temp_dir:
            vault = Path(temp_dir) / "vault"
            unrelated_note = vault / "keep.md"
            unrelated_skill = vault / ".agents" / "skills" / "my-private-skill" / "SKILL.md"
            old_managed = vault / ".agents" / "skills" / managed_name / "old.txt"
            unrelated_note.parent.mkdir(parents=True)
            unrelated_note.write_text("keep me\n", encoding="utf-8")
            unrelated_skill.parent.mkdir(parents=True)
            unrelated_skill.write_text("---\nname: my-private-skill\n---\n", encoding="utf-8")
            old_managed.parent.mkdir(parents=True)
            old_managed.write_text("old managed content\n", encoding="utf-8")

            completed = subprocess.run(
                [
                    POWERSHELL,
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(INSTALL_PATH),
                    "-VaultPath",
                    str(vault),
                ],
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(0, completed.returncode, completed.stdout + completed.stderr)
            self.assertEqual("keep me\n", unrelated_note.read_text(encoding="utf-8"))
            self.assertTrue(unrelated_skill.is_file())
            self.assertFalse(old_managed.exists())
            self.assertTrue((vault / ".agents" / "skills" / managed_name / "SKILL.md").is_file())
            backups = list((vault / ".agents" / ".codex-install-backup").glob("*"))
            self.assertEqual(1, len(backups), backups)
            self.assertTrue((backups[0] / managed_name / "old.txt").is_file())

    def test_verifier_rejects_mismatched_frontmatter(self):
        verifier = load_verifier()
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            skill = root / ".agents" / "skills" / "expected-name" / "SKILL.md"
            skill.parent.mkdir(parents=True)
            skill.write_text(
                "---\nname: wrong-name\ndescription: mismatch fixture\n---\n",
                encoding="utf-8",
            )
            findings = verifier.verify_distribution(root)
            self.assertTrue(any("frontmatter name" in finding for finding in findings), findings)

    def test_verifier_rejects_private_vault_path_literal(self):
        verifier = load_verifier()
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            core = root / ".agents" / "skills" / "obsidian-core"
            required = (
                "SKILL.md",
                "pyproject.toml",
                "references/ai-first-rules.md",
                "references/vault-schema.md",
                "scripts/build.sh",
                "scripts/vault_health.py",
                "scripts/research/research.py",
            )
            for relative in required:
                path = core / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(
                    "---\nname: obsidian-core\ndescription: fixture\n---\n"
                    if relative == "SKILL.md"
                    else "fixture\n",
                    encoding="utf-8",
                )
            (root / "README.md").write_text(
                "Never install to D:\\Cosmic Mindsea automatically.\n", encoding="utf-8"
            )

            findings = verifier.verify_distribution(root)
            self.assertTrue(any("private Vault path literal" in finding for finding in findings), findings)


if __name__ == "__main__":
    unittest.main()
