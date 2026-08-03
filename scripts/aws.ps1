[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Command
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$tofuRoot = Join-Path $repoRoot "infra/aws/eks"
$planDirectory = Join-Path $repoRoot ".plans"
$planPath = Join-Path $planDirectory "aws.tfplan"
$hashPath = Join-Path $planDirectory "aws.tfplan.sha256"

function Require-EnvironmentVariable {
    param([Parameter(Mandatory)][string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "$Name must be set."
    }
    return $value
}

$stateBucket = Require-EnvironmentVariable -Name "TF_STATE_BUCKET"
Require-EnvironmentVariable -Name "TF_VAR_admin_cidrs" | Out-Null
Require-EnvironmentVariable -Name "TF_VAR_cluster_admin_role_arn" | Out-Null

& tofu "-chdir=$tofuRoot" init `
    -backend-config="bucket=$stateBucket" `
    -backend-config="region=eu-west-3" `
    -backend-config="key=eks/kube-aegis-forge.tfstate" `
    -backend-config="use_lockfile=true"
if ($LASTEXITCODE -ne 0) { throw "OpenTofu initialization failed." }

switch ($Command) {
    "plan" {
        [System.IO.Directory]::CreateDirectory($planDirectory) | Out-Null
        & tofu "-chdir=$tofuRoot" plan "-out=$planPath"
        if ($LASTEXITCODE -ne 0) { throw "OpenTofu plan failed." }
        $hash = (Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash.ToLowerInvariant()
        [System.IO.File]::WriteAllText($hashPath, "$hash`n", [System.Text.UTF8Encoding]::new($false))
        Write-Host "Saved plan: $planPath"
        Write-Host "SHA256: $hash"
    }
    "apply" {
        if (-not (Test-Path -LiteralPath $planPath) -or -not (Test-Path -LiteralPath $hashPath)) {
            throw "No saved plan. Run task aws:plan first."
        }
        $expected = (Get-Content -LiteralPath $hashPath -Raw).Trim()
        $actual = (Get-FileHash -LiteralPath $planPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) { throw "Saved plan hash mismatch; refusing to apply." }
        if ((Read-Host "Enter APPLY to apply the saved plan") -cne "APPLY") {
            throw "Apply cancelled."
        }
        & tofu "-chdir=$tofuRoot" apply $planPath
        if ($LASTEXITCODE -ne 0) { throw "OpenTofu apply failed." }
    }
    "destroy" {
        if ((Read-Host "Enter kube-aegis-forge to destroy EKS resources") -cne "kube-aegis-forge") {
            throw "Destroy cancelled."
        }
        & tofu "-chdir=$tofuRoot" destroy
        if ($LASTEXITCODE -ne 0) { throw "OpenTofu destroy failed." }
        Write-Host "EKS resources destroyed. The bootstrap state bucket was retained."
    }
}
