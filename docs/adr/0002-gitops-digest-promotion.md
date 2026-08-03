# ADR 0002: Promote digests through a generated GitOps branch

- Status: Accepted
- Date: 2026-08-02

## Context

CI must not hold Kubernetes credentials, and mutable tags cannot prove which artifact reached an environment.

## Decision

`main` owns source code, charts, and Argo applications. The generated `gitops` branch owns only promoted environment image values. Release automation publishes the versioned chart from `main` as an immutable OCI artifact. Argo CD multi-source applications combine that chart with a verified image digest from `gitops`.

Rollback is a new GitOps commit selecting an earlier verified digest. `argocd rollback` is not used because automated synchronization would immediately restore Git state.

## Consequences

Every deployment and rollback is auditable in Git. A release can leave an unpromoted image in GHCR when a later gate fails, but the desired cluster state never changes before verification succeeds.
