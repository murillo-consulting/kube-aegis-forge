[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

& tofu fmt -check -recursive (Join-Path $repoRoot "infra")
if ($LASTEXITCODE -ne 0) { throw "OpenTofu formatting check failed." }

foreach ($root in @("infra/aws/bootstrap", "infra/aws/eks")) {
    $path = Join-Path $repoRoot $root
    & tofu "-chdir=$path" init -backend=false
    if ($LASTEXITCODE -ne 0) { throw "OpenTofu init failed for $root." }
    & tofu "-chdir=$path" validate
    if ($LASTEXITCODE -ne 0) { throw "OpenTofu validation failed for $root." }
}

$testRoot = Join-Path $repoRoot "infra/aws/eks"
& tofu "-chdir=$testRoot" test
if ($LASTEXITCODE -ne 0) { throw "OpenTofu tests failed." }

Write-Host "OpenTofu checks passed."
