[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$required = @("docker", "git", "kubectl", "helm", "kind", "tofu")
$optional = @("task", "gh", "cosign", "syft", "trivy", "gitleaks", "kubeconform", "kyverno")
$missing = @()

Write-Host "Required tools"
foreach ($tool in $required) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
        Write-Host "  [ok] $tool"
    } else {
        Write-Host "  [missing] $tool" -ForegroundColor Red
        $missing += $tool
    }
}

Write-Host "Optional validation and release tools"
foreach ($tool in $optional) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
        Write-Host "  [ok] $tool"
    } else {
        Write-Host "  [optional] $tool" -ForegroundColor Yellow
    }
}

if ($missing.Count -gt 0) {
    throw "Install the missing required tools: $($missing -join ', ')"
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Docker is installed but the daemon is not available."
}

$dockerMemory = [int64](docker info --format '{{.MemTotal}}')
$minimumMemory = 10GB
if ($dockerMemory -lt $minimumMemory) {
    throw "Docker exposes $([math]::Round($dockerMemory / 1GB, 1)) GiB; at least 10 GiB is required."
}

Write-Host "Docker memory: $([math]::Round($dockerMemory / 1GB, 1)) GiB"

$kindVersion = kind version
if ($kindVersion -notmatch "0\.32\.0") { throw "kind 0.32.0 is required; found: $kindVersion" }
$helmVersion = helm version --short
if ($helmVersion -notmatch "v4\.2\.3") { throw "Helm 4.2.3 is required; found: $helmVersion" }
$tofuVersion = (tofu version -json | ConvertFrom-Json).terraform_version
if ($tofuVersion -ne "1.12.5") { throw "OpenTofu 1.12.5 is required; found: $tofuVersion" }

Write-Host "Pinned versions: kind 0.32.0, Helm 4.2.3, OpenTofu 1.12.5"
Write-Host "Tooling check passed."
