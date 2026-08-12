[CmdletBinding()]
param(
    [string]$ProjectRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = $PSScriptRoot
}

$script:Failures = New-Object System.Collections.Generic.List[string]
$script:Warnings = New-Object System.Collections.Generic.List[string]

function Add-Pass {
    param([string]$Message)
    Write-Host "PASS: $Message" -ForegroundColor Green
}

function Add-Failure {
    param([string]$Message)
    $script:Failures.Add($Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Add-CheckWarning {
    param([string]$Message)
    $script:Warnings.Add($Message)
    Write-Host "WARN: $Message" -ForegroundColor Yellow
}

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    throw "Project root does not exist: $ProjectRoot"
}

$root = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path)
$requiredPaths = @(
    '.agents\skills',
    '_CLAUDE.md',
    '.vault-config.json',
    'README.md',
    'LICENSE',
    'NOTICE.md',
    '.gitignore',
    'install.ps1',
    'docs\architecture.md',
    'docs\privacy.md',
    'docs\upstream.md'
)

foreach ($relative in $requiredPaths) {
    $path = Join-Path $root $relative
    if (Test-Path -LiteralPath $path) {
        Add-Pass "required path exists: $relative"
    }
    else {
        Add-Failure "required path is missing: $relative"
    }
}

$configPath = Join-Path $root '.vault-config.json'
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        $null = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Add-Pass '.vault-config.json is valid JSON'
    }
    catch {
        Add-Failure ".vault-config.json is invalid JSON: $($_.Exception.Message)"
    }
}

$skillsRoot = Join-Path $root '.agents\skills'
if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
    $skillDirectories = @(Get-ChildItem -LiteralPath $skillsRoot -Directory -Force)
    if ($skillDirectories.Count -eq 46) {
        Add-Pass 'found exactly 46 top-level Skill directories'
    }
    else {
        Add-Failure "expected 46 top-level Skill directories, found $($skillDirectories.Count)"
    }

    $missingSkillFiles = @()
    foreach ($directory in $skillDirectories) {
        if (-not (Test-Path -LiteralPath (Join-Path $directory.FullName 'SKILL.md') -PathType Leaf)) {
            $missingSkillFiles += $directory.Name
        }
    }
    if ($missingSkillFiles.Count -eq 0) {
        Add-Pass 'every top-level Skill directory contains SKILL.md'
    }
    else {
        Add-Failure ("Skill directories missing SKILL.md: " + ($missingSkillFiles -join ', '))
    }
}

$allItems = @(Get-ChildItem -LiteralPath $root -Recurse -Force)
$excludedItems = @($allItems | Where-Object {
    $_.FullName -match '[\\/](\.venv|\.deps|__pycache__)([\\/]|$)' -or
    (-not $_.PSIsContainer -and $_.Extension -eq '.pyc')
})
if ($excludedItems.Count -eq 0) {
    Add-Pass 'no Python runtime, installed dependency, cache, or .pyc artifacts found'
}
else {
    Add-Failure ("excluded runtime artifacts found: " + (($excludedItems | Select-Object -First 10 -ExpandProperty FullName) -join '; '))
}

$privateRootNames = @(
    '.obsidian', '.codex-install-backup', '.cache', '.runtime',
    'Bases', 'Ideas', 'Knowledge', 'Learning', 'Logs', 'Projects', 'Research',
    'Daily', 'Tasks', 'Boards', 'People', 'Templates', 'Dev Logs'
)
$presentPrivateRoots = @($privateRootNames | Where-Object { Test-Path -LiteralPath (Join-Path $root $_) })
if ($presentPrivateRoots.Count -eq 0) {
    Add-Pass 'no private Vault content roots are present'
}
else {
    Add-Failure ("private Vault content roots found: " + ($presentPrivateRoots -join ', '))
}

$secretPatterns = @(
    [pscustomobject]@{ Name = 'OpenAI-style API key'; Pattern = '(?i)sk-(?:proj-)?[A-Za-z0-9_-]{20,}' },
    [pscustomobject]@{ Name = 'Anthropic API key'; Pattern = '(?i)sk-ant-[A-Za-z0-9_-]{20,}' },
    [pscustomobject]@{ Name = 'GitHub token'; Pattern = '(?i)gh[pousr]_[A-Za-z0-9]{20,}' },
    [pscustomobject]@{ Name = 'Google API key'; Pattern = 'AIza[0-9A-Za-z_-]{30,}' },
    [pscustomobject]@{ Name = 'AWS access key'; Pattern = 'AKIA[0-9A-Z]{16}' },
    [pscustomobject]@{ Name = 'Private key'; Pattern = '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----' },
    [pscustomobject]@{ Name = 'Quoted credential assignment'; Pattern = '(?im)(?:api[_-]?key|token|secret|password)\s*[:=]\s*["''][^"''\r\n]{12,}["'']' }
)

$textExtensions = @('.md', '.py', '.ps1', '.sh', '.toml', '.json', '.jsonl', '.lock', '.template', '.gitignore')
$secretFindings = New-Object System.Collections.Generic.List[string]
foreach ($file in @($allItems | Where-Object { -not $_.PSIsContainer })) {
    $extension = $file.Extension.ToLowerInvariant()
    if ($file.Name -eq '.gitignore') {
        $extension = '.gitignore'
    }
    if ($textExtensions -notcontains $extension) {
        continue
    }

    try {
        $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    }
    catch {
        Add-CheckWarning "could not read text file for credential scan: $($file.FullName)"
        continue
    }

    foreach ($secretPattern in $secretPatterns) {
        if ($text -match $secretPattern.Pattern) {
            $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/')
            $secretFindings.Add("$($secretPattern.Name) in $relative")
        }
    }
}

if ($secretFindings.Count -eq 0) {
    Add-Pass 'no high-confidence credential patterns found'
}
else {
    Add-Failure ("credential findings: " + (($secretFindings | Select-Object -Unique) -join '; '))
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
if ($null -ne $pythonCommand) {
    $pythonCheck = @'
import ast
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
excluded = {'.venv', '.deps', '__pycache__'}
files = [
    path for path in root.rglob('*.py')
    if not excluded.intersection(path.relative_to(root).parts)
]
errors = []
for path in files:
    try:
        ast.parse(path.read_text(encoding='utf-8-sig'), filename=str(path))
    except Exception as exc:
        errors.append(f'{path}: {exc}')
print(f'PYTHON_FILES={len(files)}')
for error in errors:
    print(error, file=sys.stderr)
raise SystemExit(1 if errors else 0)
'@
    $pythonOutput = & $pythonCommand.Source -c $pythonCheck $root 2>&1
    if ($LASTEXITCODE -eq 0) {
        Add-Pass ("Python AST parsing succeeded; " + ($pythonOutput -join ' '))
    }
    else {
        Add-Failure ("Python AST parsing failed: " + ($pythonOutput -join ' '))
    }
}
else {
    Add-CheckWarning 'python command not found; Python AST parsing was skipped'
}

Write-Host ''
Write-Host "Verification summary: $($script:Failures.Count) failure(s), $($script:Warnings.Count) warning(s)."
if ($script:Failures.Count -gt 0) {
    exit 1
}
exit 0
