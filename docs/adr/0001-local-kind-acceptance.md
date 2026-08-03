# ADR 0001: Make local kind the mandatory acceptance environment

- Status: Accepted
- Date: 2026-08-02

## Context

The portfolio must be reproducible without a cloud account or ongoing cost while still exercising Kubernetes, GitOps, admission policy, and observability.

## Decision

The definition of done is `task local:up` followed by `task local:verify` on a pinned three-node kind cluster. AWS EKS remains an optional extension.

## Consequences

Every required capability must work within a 10 GiB Docker memory budget. The local topology proves control flow and resilience but not cloud load balancer, multi-AZ failure, or managed control-plane behavior. `task local:down` targets only `kube-aegis-forge` for safe cleanup.

