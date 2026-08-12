[CmdletBinding()]
param(
    [string]$ProjectRoot = $PSScriptRoot,
    [string]$CompareGenerated
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = $PSScriptRoot
}
$project = [System.IO.Path]::GetFullPath($ProjectRoot)
$verifier = Join-Path $project 'tools\verify_distribution.py'

if (-not (Test-Path -LiteralPath $verifier -PathType Leaf)) {
    throw "Verifier not found: $verifier"
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
    $python = Get-Command py -ErrorAction SilentlyContinue
}
if (-not $python) {
    throw 'Python 3.10+ was not found on PATH.'
}

$arguments = @($verifier, '--root', $project)
if ($CompareGenerated) {
    $arguments += @('--compare-generated', [System.IO.Path]::GetFullPath($CompareGenerated))
}

& $python.Source @arguments
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
