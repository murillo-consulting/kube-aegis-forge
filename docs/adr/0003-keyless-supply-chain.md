# ADR 0003: Use keyless signing and verifiable attestations

- Status: Accepted
- Date: 2026-08-02

## Context

Long-lived signing keys create storage, rotation, and compromise risk. A signature alone does not describe how an image was built.

## Decision

GitHub OIDC obtains short-lived Fulcio certificates. The release workflow signs the exact digest with Cosign, publishes the large Syft SPDX SBOM as an OCI 1.1 bundle, attaches a compact SLSA v1 predicate in Kyverno-compatible form, and also publishes native GitHub provenance. It verifies every evidence type before promotion. Kyverno admits only the repository image signed and attested by the exact release workflow identity.

## Consequences

The design depends on GitHub OIDC, Fulcio/Rekor, and GHCR availability during releases and first-time admissions. Two Cosign storage representations are intentional: OCI 1.1 avoids feeding a multi-megabyte SBOM into Kyverno's two-megabyte admission context, while the compact attached provenance remains readable by `ClusterPolicy.verifyImages`. Verification identity must be updated deliberately if the workflow path or repository name changes.
