# Runbook: digest rollback

## Preconditions

- identify the digest previously produced by `release.yml`;
- confirm it predates the incident and is still acceptable under the current vulnerability policy;
- obtain approval for the target GitHub environment.

## Procedure

1. Open **Actions → Roll back GitOps digest → Run workflow**.
2. Select `local` or `aws` and paste the full `sha256:…` digest.
3. Review the verification step. It must validate the Cosign signature, SPDX attestation, and GitHub provenance.
4. Approve the environment when required.
5. Confirm a new `rollback(environment): repository@digest` commit appears on
   `gitops`.
6. Wait for Argo CD to report `Synced/Healthy`, then execute the functional checks.

## Failure handling

If evidence verification fails, the workflow must not change `gitops`. Investigate the digest selection; do not weaken Kyverno or manually patch the Deployment. If Argo cannot reconcile a verified digest, follow the Argo diagnostics runbook.
