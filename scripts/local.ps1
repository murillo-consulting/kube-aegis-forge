[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("up", "verify", "status", "down")]
    [string]$Command
)

$ErrorActionPreference = "Stop"
$clusterName = "kube-aegis-forge"
$context = "kind-$clusterName"
$repoRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Checked {
    param([Parameter(Mandatory)][scriptblock]$Script)
    & $Script
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE."
    }
}

function Test-ClusterExists {
    # --quiet avoids kind's informational stderr message when no cluster exists,
    # which Windows PowerShell otherwise promotes to a terminating error.
    $clusters = @(kind get clusters --quiet)
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to enumerate kind clusters (exit code $LASTEXITCODE)."
    }
    return $clusters -contains $clusterName
}

function New-GrafanaSecret {
    Invoke-Checked { kubectl --context $context create namespace monitoring --dry-run=client -o yaml | kubectl --context $context apply -f - }

    $temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("devsecops-grafana-" + [guid]::NewGuid())
    [System.IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
    try {
        $usernamePath = Join-Path $temporaryDirectory "admin-user"
        $passwordPath = Join-Path $temporaryDirectory "admin-password"
        [System.IO.File]::WriteAllText($usernamePath, "admin", [System.Text.UTF8Encoding]::new($false))

        $randomBytes = [byte[]]::new(32)
        $randomNumberGenerator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        try {
            $randomNumberGenerator.GetBytes($randomBytes)
        } finally {
            $randomNumberGenerator.Dispose()
        }
        $password = [Convert]::ToBase64String($randomBytes).TrimEnd("=").Replace("+", "-").Replace("/", "_")
        [System.IO.File]::WriteAllText($passwordPath, $password, [System.Text.UTF8Encoding]::new($false))

        Invoke-Checked {
            kubectl --context $context -n monitoring create secret generic grafana-admin `
                --from-file="admin-user=$usernamePath" `
                --from-file="admin-password=$passwordPath" `
                --dry-run=client -o yaml |
                kubectl --context $context apply -f -
        }
    } finally {
        if (Test-Path -LiteralPath $temporaryDirectory) {
            Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force
        }
    }
}

function Start-Platform {
    & (Join-Path $PSScriptRoot "tools-check.ps1")

    if (-not (Test-ClusterExists)) {
        Invoke-Checked {
            kind create cluster --name $clusterName --config (Join-Path $repoRoot "platform/kind/cluster.yaml") --wait 180s
        }
    } else {
        Write-Host "Cluster $clusterName already exists; reusing it."
    }

    New-GrafanaSecret
    Invoke-Checked { helm repo add argo https://argoproj.github.io/argo-helm --force-update }
    Invoke-Checked { helm repo update argo }
    Invoke-Checked {
        helm upgrade --install argocd argo/argo-cd `
            --kube-context $context `
            --namespace argocd `
            --create-namespace `
            --version 10.2.2 `
            --values (Join-Path $repoRoot "platform/bootstrap/argocd-values.yaml") `
            --wait `
            --timeout 10m
    }
    Invoke-Checked { kubectl --context $context apply -f (Join-Path $repoRoot "platform/bootstrap/root-local.yaml") }

    Write-Host "Bootstrap complete. Argo CD is reconciling the platform."
    Write-Host "Run 'task local:verify' once the applications are synchronized."
}

function Assert-HttpEndpoint {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Expected
    )
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:8080$Path" -TimeoutSec 10
    if ($response.StatusCode -ne 200 -or -not $response.Content.Contains($Expected)) {
        throw "Endpoint $Path did not satisfy its contract."
    }
    Write-Host "  [ok] $Path"
}

function Wait-ForApplication {
    param([Parameter(Mandatory)][string]$Name)
    $deadline = (Get-Date).AddMinutes(20)
    while ((Get-Date) -lt $deadline) {
        $state = kubectl --context $context -n argocd get application $Name -o json 2>$null | ConvertFrom-Json
        if ($state.status.sync.status -eq "Synced" -and $state.status.health.status -eq "Healthy") {
            Write-Host "  [ok] $Name is Synced/Healthy"
            return
        }
        Start-Sleep -Seconds 10
    }
    kubectl --context $context -n argocd get application $Name -o yaml
    throw "Argo application $Name did not become Synced/Healthy."
}

function Test-Platform {
    if (-not (Test-ClusterExists)) {
        throw "Cluster $clusterName does not exist. Run task local:up first."
    }

    Invoke-Checked { kubectl --context $context wait --for=condition=Ready nodes --all --timeout=5m }
    foreach ($application in @("platform-common", "traefik", "metrics-server", "kyverno", "monitoring", "security-policies", "demo-api", "platform-root")) {
        Wait-ForApplication -Name $application
    }
    Invoke-Checked { kubectl --context $context -n demo wait deployment/demo-api --for=condition=Available --timeout=5m } # gitleaks:allow

    Assert-HttpEndpoint -Path "/" -Expected '"name":"devsecops-demo-api"'
    Assert-HttpEndpoint -Path "/health/live" -Expected '"status":"ok"'
    Assert-HttpEndpoint -Path "/health/ready" -Expected '"status":"ready"'
    Assert-HttpEndpoint -Path "/metrics" -Expected "demo_api_http_requests_total"

    Invoke-Checked { kubectl --context $context -n demo get servicemonitor demo-api }
    Invoke-Checked { kubectl --context $context -n demo get prometheusrule demo-api }
    Invoke-Checked { kubectl --context $context -n demo get configmap demo-api-dashboard }
    Invoke-Checked { kubectl --context $context -n demo get resourcequota demo-api-quota }
    Invoke-Checked { kubectl --context $context -n demo get limitrange demo-api-limits }
    Invoke-Checked { kubectl --context $context get clusterpolicy demo-workload-hardening verify-demo-image }
    $automount = kubectl --context $context -n demo get deployment demo-api -o jsonpath='{.spec.template.spec.automountServiceAccountToken}'
    if ($automount -ne "false") {
        throw "The application service account token is mounted automatically."
    }

    $badPod = Join-Path $repoRoot "platform/policies/tests/unsigned-pod.yaml"
    # PowerShell 5 promotes native stderr to an error record when the global
    # preference is Stop. This command is expected to fail, so capture its
    # exit code without allowing the intentional Kyverno denial to terminate
    # the verification script.
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $denialOutput = & kubectl --context $context apply --dry-run=server -f $badPod 2>&1
    $badPodExitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($badPodExitCode -eq 0) {
        throw "Kyverno accepted the intentionally invalid workload."
    }
    $denialText = ($denialOutput | Out-String).Trim()
    Write-Host $denialText
    if (-not $denialText.Contains("verify-demo-image")) {
        throw "The negative control was not rejected by the image-verification policy."
    }
    Write-Host "  [ok] Kyverno rejected the unsigned image digest"

    $targets = kubectl --context $context get --raw "/api/v1/namespaces/monitoring/services/http:monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/targets"
    if (-not $targets.Contains('"job":"demo-api"') -or -not $targets.Contains('"health":"up"')) {
        throw "Prometheus does not report the demo-api target as UP."
    }
    Write-Host "  [ok] Prometheus target is UP"

    $oldPod = kubectl --context $context -n demo get pod -l app.kubernetes.io/name=demo-api -o jsonpath='{.items[0].metadata.name}'
    Invoke-Checked { kubectl --context $context -n demo delete pod $oldPod --wait=false }
    Invoke-Checked { kubectl --context $context -n demo wait deployment/demo-api --for=condition=Available --timeout=3m } # gitleaks:allow
    $newPods = kubectl --context $context -n demo get pod -l app.kubernetes.io/name=demo-api -o name
    if ($newPods -match [regex]::Escape("pod/$oldPod")) {
        Start-Sleep -Seconds 5
    }
    Write-Host "  [ok] Kubernetes recreated the deleted replica"

    Invoke-Checked { kubectl --context $context -n demo scale deployment demo-api --replicas=1 }
    $deadline = (Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Seconds 5
        $replicas = kubectl --context $context -n demo get deployment demo-api -o jsonpath='{.spec.replicas}'
    } while ($replicas -ne "2" -and (Get-Date) -lt $deadline)
    if ($replicas -ne "2") {
        throw "Argo CD did not self-heal the replica drift."
    }
    Write-Host "  [ok] Argo CD self-healed an allowed drift"
    Write-Host "Local verification passed."
}

function Show-Status {
    if (-not (Test-ClusterExists)) {
        Write-Host "Cluster $clusterName is not running."
        return
    }
    kubectl --context $context get nodes
    kubectl --context $context -n argocd get applications
    kubectl --context $context -n demo get deployments,pods,services,ingresses 2>$null
    Write-Host "Application: http://localhost:8080"
    Write-Host "Argo CD: task local:port-forward:argocd"
    Write-Host "Grafana: task local:port-forward:grafana"
    Write-Host "Prometheus: task local:port-forward:prometheus"
}

switch ($Command) {
    "up" { Start-Platform }
    "verify" { Test-Platform }
    "status" { Show-Status }
    "down" {
        if (Test-ClusterExists) {
            Invoke-Checked { kind delete cluster --name $clusterName }
        } else {
            Write-Host "Cluster $clusterName does not exist."
        }
    }
}
