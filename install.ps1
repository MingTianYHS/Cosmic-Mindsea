[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$VaultPath,

    [string]$ProjectRoot = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-FullPath([string]$PathValue) {
    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        throw 'Path value must not be empty.'
    }
    return [System.IO.Path]::GetFullPath($PathValue)
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = $PSScriptRoot
}

$project = Resolve-FullPath $ProjectRoot
$vault = Resolve-FullPath $VaultPath
$sourceSkills = Join-Path $project '.agents\skills'

if (-not (Test-Path -LiteralPath $sourceSkills -PathType Container)) {
    throw "Source skills directory not found: $sourceSkills"
}

if (-not (Test-Path -LiteralPath $vault -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($vault, 'Create Vault directory')) {
        New-Item -ItemType Directory -Path $vault -Force | Out-Null
    }
}

$destinationSkills = Join-Path $vault '.agents\skills'
$managedSkills = @(Get-ChildItem -LiteralPath $sourceSkills -Directory | Sort-Object Name)
if ($managedSkills.Count -eq 0) {
    throw "No managed Skill directories found: $sourceSkills"
}

$collisions = @($managedSkills | Where-Object {
    Test-Path -LiteralPath (Join-Path $destinationSkills $_.Name)
})
$backupRoot = $null

if ($collisions.Count -gt 0) {
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
    $backupRoot = Join-Path $vault ".agents\.codex-install-backup\$stamp"
    Write-Host "Same-name managed Skills will be backed up under: $backupRoot"
}

if ($WhatIfPreference) {
    foreach ($skill in $managedSkills) {
        $target = Join-Path $destinationSkills $skill.Name
        Write-Host "Would install: $($skill.Name) -> $target"
    }
    return
}

New-Item -ItemType Directory -Path $destinationSkills -Force | Out-Null
if ($backupRoot) {
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
}

foreach ($skill in $managedSkills) {
    $target = Join-Path $destinationSkills $skill.Name
    if (Test-Path -LiteralPath $target) {
        $backup = Join-Path $backupRoot $skill.Name
        Copy-Item -LiteralPath $target -Destination $backup -Recurse
        Remove-Item -LiteralPath $target -Recurse -Force
    }
    Copy-Item -LiteralPath $skill.FullName -Destination $target -Recurse
    Write-Host "Installed: $($skill.Name)"
}

Write-Host "Installation complete: $($managedSkills.Count) managed Skills copied to $destinationSkills"
if ($backupRoot) {
    Write-Host "Backup created: $backupRoot"
}
