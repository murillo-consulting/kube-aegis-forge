# ADR 0008: Explicit, testable AWS security baseline

- Status: Accepted
- Date: 2026-08-03

## Context

The optional AWS architecture previously relied on several secure module defaults and broad AWS managed policies. That was difficult to audit from the root module and weak portfolio evidence even when the effective defaults were safe.

## Decision

Make the cloud security contract explicit in the root modules and test it without provisioning AWS:

- encrypt retained state and EKS secrets with rotating customer-managed KMS keys;
- enable every EKS control-plane log type and VPC Flow Logs with 30-day retention;
- require IMDSv2, encrypted worker root volumes, private nodes, and narrow API CIDRs;
- disable implicit cluster-creator administration and require a named IAM role through an EKS access entry;
- install EKS Pod Identity and disable unused legacy IRSA/OIDC resources;
- replace `ReadOnlyAccess` and `PowerUserAccess` with service-specific, region-constrained OIDC policies, and prevent the plan identity from writing the state object;
- run mocked OpenTofu assertions and a blocking Trivy IaC scan in CI.

## Consequences

The repository can prove its cloud controls without an AWS account or cloud spend. A real deployment still requires an existing administrator role and an reviewed AWS plan. The KMS keys, CloudWatch logs, NAT Gateway, EKS control plane, and worker nodes incur charges if applied; no deployment is part of local acceptance.
