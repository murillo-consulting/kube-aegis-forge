[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot

docker run --rm `
    --volume "${repoRoot}:/workspace:ro" `
    --workdir /workspace `
    aquasec/trivy@sha256:cffe3f5161a47a6823fbd23d985795b3ed72a4c806da4c4df16266c02accdd6f `
    config `
    --severity HIGH,CRITICAL `
    --exit-code 1 `
    --tf-exclude-downloaded-modules `
    --skip-dirs /workspace/infra/aws/bootstrap/.terraform `
    --skip-dirs /workspace/infra/aws/eks/.terraform `
    /workspace/infra
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

docker run --rm `
    --volume "${repoRoot}:/workspace:ro" `
    ghcr.io/kyverno/kyverno-cli@sha256:7224ed05508c24419c3df98114c28ba682ad0a940dcdb7b9fdba0a4b6bf943cf `
    test /workspace/platform/policies/tests
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
