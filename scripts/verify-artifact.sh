#!/usr/bin/env bash
set -euo pipefail

image_ref="${1:?usage: verify-artifact.sh IMAGE@sha256:DIGEST}"
oidc_issuer="https://token.actions.githubusercontent.com"

case "$image_ref" in
  ghcr.io/murillo-consulting/kube-aegis-forge@sha256:*)
    certificate_identity="https://github.com/murillo-consulting/kube-aegis-forge/.github/workflows/release.yml@refs/heads/main"
    attestation_repository="murillo-consulting/kube-aegis-forge"
    ;;
  *)
    printf 'Unsupported artifact repository or non-digest reference: %s\n' \
      "$image_ref" >&2
    exit 2
    ;;
esac

cosign verify \
  --new-bundle-format=false \
  --certificate-identity "$certificate_identity" \
  --certificate-oidc-issuer "$oidc_issuer" \
  "$image_ref" >/dev/null
printf 'Cosign signature verified.\n'

cosign verify-attestation \
  --type spdxjson \
  --certificate-identity "$certificate_identity" \
  --certificate-oidc-issuer "$oidc_issuer" \
  "$image_ref" >/dev/null
printf 'SPDX SBOM attestation verified.\n'

cosign verify-attestation \
  --new-bundle-format=false \
  --type slsaprovenance1 \
  --certificate-identity "$certificate_identity" \
  --certificate-oidc-issuer "$oidc_issuer" \
  "$image_ref" >/dev/null
printf 'Admission-compatible SLSA provenance verified.\n'

gh attestation verify "oci://$image_ref" \
  --repo "$attestation_repository"
printf 'GitHub build provenance verified.\n'
