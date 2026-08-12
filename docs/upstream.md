# Upstream relationship

## Source

- Repository: <https://github.com/eugeniughelbur/obsidian-second-brain>
- Upstream author: Eugeniu Ghelbur
- License: MIT
- Installed version represented here: `0.14.0`

## What is represented in this repository

`.agents/skills` is the Agent Skills installation output used by the Cosmic Mindsea Vault. It includes the executable instructions and supporting code needed by an Agent at runtime.

The full upstream development repository additionally contains canonical command sources, adapters, tests, CI workflows, release scripts, contribution documentation, and other platform distributions. Those are not reconstructed here because this project records the real deployed Cosmic Mindsea tool boundary.

## Recommended maintenance model

Use two references during substantial development:

1. this repository, to preserve Cosmic Mindsea's deployed rules, instance configuration, Windows installation, and release boundary;
2. a Fork or clone of the complete upstream repository, to modify canonical command sources and run the complete upstream test/build pipeline.

When importing a newer upstream release:

1. identify the exact upstream tag or commit;
2. build the Agent Skills distribution from the full upstream repository;
3. compare generated output with this repository;
4. reapply Cosmic Mindsea-specific governance, configuration, installation, and privacy changes as explicit commits;
5. run `verify.ps1` and an installation test against an isolated Vault;
6. update `NOTICE.md` with the new upstream version or commit.

## Contributing upstream

General improvements such as Windows path handling, Unicode tests, installer portability, provider controls, documentation corrections, and generated-output consistency checks should be proposed upstream when they are not Cosmic Mindsea-specific. This reduces long-term fork drift.

