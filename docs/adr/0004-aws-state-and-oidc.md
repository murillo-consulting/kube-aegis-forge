# ADR 0004: Separate retained state and short-lived AWS roles

- Status: Accepted
- Date: 2026-08-02

## Context

The optional AWS extension needs durable state and automation credentials without committing access keys or allowing a plan job to mutate infrastructure.

## Decision

A separately applied bootstrap root creates a versioned, encrypted, public-blocked S3 bucket with native lockfiles and `prevent_destroy`. It also creates distinct GitHub OIDC roles:

- `plan` trusts the protected `aws` environment and receives read-only infrastructure plus state-lock access;
- `apply` trusts the approval-gated `aws-apply` environment and receives the permissions required to manage project resources.

GitHub environment deployment-branch rules restrict both environments to `main`. This is required because the OIDC `sub` claim contains the environment name instead of the branch when environments are used.

## Consequences

No AWS key is stored in GitHub. The state bucket intentionally survives EKS destruction and requires a separate, documented cleanup procedure. Operators must configure environment protection rules and repository variables after bootstrap.

