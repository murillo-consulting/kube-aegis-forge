# ADR 0006: Use an OCI chart as the GitOps source boundary

- Status: Accepted
- Date: 2026-08-02

## Context

The application chart is versioned on `main`, while the promoted image digest is the only generated state on the `gitops` branch. Argo CD normalizes repository URLs and deliberately rejects a multi-source application that references different revisions of the same Git repository. Keeping both sources as Git therefore prevents reconciliation.

## Decision

Release automation packages the reviewed chart from `main` and publishes it as a versioned immutable OCI artifact, currently `ghcr.io/murillo-consulting/kube-aegis-forge:0.3.0`. If that version already exists, the workflow expands both archives and fails unless their contents match. Argo CD reads the chart from GHCR and the image values from the `gitops` branch, which are genuinely independent sources.

Chart changes require an explicit version bump. The chart shares the already-public project OCI repository with the application image and remains anonymously readable by local and AWS clusters.

## Consequences

The multi-source contract works without repository URL tricks or Kubernetes credentials in CI. Chart versions are immutable and auditable, but a chart change is a release event and cannot silently reuse an existing version.
