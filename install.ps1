[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$VaultPath,

    [Parameter(DontShow = $true)]
    [ValidateSet('AfterBackup')]
    [string]$TestFailurePoint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}

function Test-PathWithinRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $candidateFull = Get-FullPath -Path $Candidate
    $rootFull = Get-FullPath -Path $Root
    if ($candidateFull.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $prefix = $rootFull + [System.IO.Path]::DirectorySeparatorChar
    return $candidateFull.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-ManagedTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$VaultRoot
    )

    if (-not (Test-PathWithinRoot -Candidate $Candidate -Root $VaultRoot)) {
        throw "Refusing to operate outside the target Vault: $Candidate"
    }
}

function Copy-CleanDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $excludedSegments = @('.venv', '.deps', '__pycache__')
    [System.IO.Directory]::CreateDirectory($Destination) | Out-Null

    foreach ($item in Get-ChildItem -LiteralPath $Source -Recurse -Force) {
        $relative = $item.FullName.Substring($Source.Length).TrimStart('\', '/')
        if ([string]::IsNullOrWhiteSpace($relative)) {
            continue
        }

        $segments = $relative -split '[\\/]'
        if (@($segments | Where-Object { $excludedSegments -contains $_ }).Count -gt 0) {
            continue
        }
        if (-not $item.PSIsContainer -and $item.Extension -eq '.pyc') {
            continue
        }

        $target = Join-Path $Destination $relative
        if ($item.PSIsContainer) {
            [System.IO.Directory]::CreateDirectory($target) | Out-Null
        }
        else {
            $parent = Split-Path -Parent $target
            [System.IO.Directory]::CreateDirectory($parent) | Out-Null
            Copy-Item -LiteralPath $item.FullName -Destination $target -Force
        }
    }
}

$projectRoot = Get-FullPath -Path $PSScriptRoot
$skillsSource = Join-Path $projectRoot '.agents\skills'
$manualSource = Join-Path $projectRoot '_CLAUDE.md'
$configSource = Join-Path $projectRoot '.vault-config.json'

foreach ($required in @($skillsSource, $manualSource, $configSource)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Distribution is incomplete; required source is missing: $required"
    }
}

if (-not (Test-Path -LiteralPath $VaultPath -PathType Container)) {
    throw "Target Vault directory does not exist. Create it explicitly, then rerun: $VaultPath"
}

$vaultRoot = Get-FullPath -Path (Resolve-Path -LiteralPath $VaultPath).Path
if (
    (Test-PathWithinRoot -Candidate $projectRoot -Root $vaultRoot) -or
    (Test-PathWithinRoot -Candidate $vaultRoot -Root $projectRoot)
) {
    throw 'The repository and target Vault must be separate, non-nested directories.'
}

$managedTargets = @(
    [pscustomobject]@{
        Relative = '.agents\skills'
        Source = $skillsSource
        IsDirectory = $true
    },
    [pscustomobject]@{
        Relative = '_CLAUDE.md'
        Source = $manualSource
        IsDirectory = $false
    },
    [pscustomobject]@{
        Relative = '.vault-config.json'
        Source = $configSource
        IsDirectory = $false
    }
)

Write-Host 'Cosmic Mindsea Knowledge System deployment plan:'
foreach ($entry in $managedTargets) {
    Write-Host ("  {0} -> {1}" -f $entry.Source, (Join-Path $vaultRoot $entry.Relative))
}

$action = 'Back up existing managed surfaces and install .agents/skills, _CLAUDE.md, and .vault-config.json'
if (-not $PSCmdlet.ShouldProcess($vaultRoot, $action)) {
    Write-Host 'No files were changed.'
    return
}

$timestamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$backupRoot = Join-Path $vaultRoot ('.codex-install-backup\' + $timestamp)
$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('cosmic-mindsea-install-' + [Guid]::NewGuid().ToString('N'))
$movedBackups = New-Object System.Collections.Generic.List[object]
$installedTargets = New-Object System.Collections.Generic.List[string]

try {
    [System.IO.Directory]::CreateDirectory($stageRoot) | Out-Null
    $stageSkills = Join-Path $stageRoot '.agents\skills'
    Copy-CleanDirectory -Source $skillsSource -Destination $stageSkills
    Copy-Item -LiteralPath $manualSource -Destination (Join-Path $stageRoot '_CLAUDE.md') -Force
    Copy-Item -LiteralPath $configSource -Destination (Join-Path $stageRoot '.vault-config.json') -Force

    foreach ($entry in $managedTargets) {
        $target = Join-Path $vaultRoot $entry.Relative
        Assert-ManagedTarget -Candidate $target -VaultRoot $vaultRoot

        if (Test-Path -LiteralPath $target) {
            $backup = Join-Path $backupRoot $entry.Relative
            Assert-ManagedTarget -Candidate $backup -VaultRoot $vaultRoot
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $backup)) | Out-Null
            Move-Item -LiteralPath $target -Destination $backup
            $movedBackups.Add([pscustomobject]@{ Target = $target; Backup = $backup })
        }
    }

    if ($TestFailurePoint -eq 'AfterBackup') {
        throw 'Injected test failure after backup.'
    }

    $targetSkills = Join-Path $vaultRoot '.agents\skills'
    Assert-ManagedTarget -Candidate $targetSkills -VaultRoot $vaultRoot
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $targetSkills)) | Out-Null
    $installedTargets.Add($targetSkills)
    Copy-CleanDirectory -Source $stageSkills -Destination $targetSkills

    foreach ($relativeFile in @('_CLAUDE.md', '.vault-config.json')) {
        $sourceFile = Join-Path $stageRoot $relativeFile
        $targetFile = Join-Path $vaultRoot $relativeFile
        Assert-ManagedTarget -Candidate $targetFile -VaultRoot $vaultRoot
        $installedTargets.Add($targetFile)
        Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
    }

    Write-Host 'Installation completed.' -ForegroundColor Green
    if ($movedBackups.Count -gt 0) {
        Write-Host "Previous managed files were backed up to: $backupRoot"
    }
    else {
        Write-Host 'No previous managed files required backup.'
    }
}
catch {
    Write-Warning "Installation failed; attempting rollback: $($_.Exception.Message)"

    for ($index = $installedTargets.Count - 1; $index -ge 0; $index--) {
        $target = $installedTargets[$index]
        Assert-ManagedTarget -Candidate $target -VaultRoot $vaultRoot
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
    }

    for ($index = $movedBackups.Count - 1; $index -ge 0; $index--) {
        $record = $movedBackups[$index]
        if (Test-Path -LiteralPath $record.Backup) {
            [System.IO.Directory]::CreateDirectory((Split-Path -Parent $record.Target)) | Out-Null
            Move-Item -LiteralPath $record.Backup -Destination $record.Target
        }
    }

    throw
}
finally {
    if (Test-Path -LiteralPath $stageRoot) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force
    }
}
