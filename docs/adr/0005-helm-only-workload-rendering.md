# ADR 0005: Use Helm without Kustomize

- Status: Accepted
- Date: 2026-08-02

## Context

The workload needs local and AWS profiles, policy-safe defaults, and multi-source digest injection. Adding a second overlay engine would increase the number of render paths.

## Decision

One Helm chart exposes explicit values for image, replicas, resources, ingress, monitoring, network policy, and autoscaling. Environment values override the defaults; the generated GitOps file supplies only image and build metadata.

## Consequences

There is one render and validation path. Environment-specific differences remain small and visible. More complex future platform composition may justify reevaluating this decision.

