# Runbook: image or supply-chain incident

## Trigger

Use this procedure for a new exploitable CVE, unexpected package, invalid signature, missing attestation, GHCR compromise signal, or behavior inconsistent with the promoted source commit.

## Containment

1. Disable or pause release/promotion workflows through repository administration if compromise is suspected.
2. Record the active environment digest and relevant workflow run IDs.
3. Verify the digest independently with `scripts/verify-artifact.sh`.
4. If a previously verified safe digest exists, execute the rollback workflow.
5. Do not delete the suspect digest, attestations, Git history, or logs until evidence collection is complete.

## Investigation

- compare the image configuration and SBOM to the expected commit;
- inspect the Trivy database timestamp and ignored/unfixed findings;
- verify certificate identity, issuer, Rekor entry, provenance source repository, and workflow ref;
- inspect workflow changes and maintainer activity around the release;
- review Kubernetes events, policy reports, and application logs.

## Recovery

Patch dependencies or code on a reviewed branch, merge through required checks, and allow the normal release to produce a new digest. Confirm verification and local E2E before promoting AWS. Document the root cause, timeline, affected digests, and control improvement in the incident record and an ADR when architecture changes.

