# Runbook: offline AWS security review

This procedure validates the optional AWS design without credentials, AWS API calls, or cloud spend.

## Execute the reproducible checks

```bash
task tools:check
task tofu:check
task security:check
```

The OpenTofu tests use mocked providers. They assert retained-state protection, KMS rotation, S3 public-access blocks, short OIDC sessions, explicit EKS administration, all control-plane logs, VPC Flow Logs, and IMDSv2. Trivy independently blocks High or Critical IaC misconfigurations.

The plan role can read the exact state object and create or remove only its `.tflock` object. State writes are reserved for the separately approved apply role.

## Review the interfaces

- `admin_cidrs` accepts only IPv4 `/24`-or-narrower or IPv6 `/64`-or-narrower networks;
- `cluster_admin_role_arn` must identify an existing IAM role and becomes the sole declared cluster administrator;
- the `security_baseline` output summarizes non-sensitive controls for plan review;
- GitHub `aws` can plan, while approval-gated `aws-apply` owns apply and destroy.

## Boundary of the proof

These checks prove configuration syntax, module wiring, policy assertions, and static security rules. They do not prove AWS service availability, account-level SCPs, runtime log delivery, or successful IAM authorization. Claim real AWS deployment evidence only after an authorized plan/apply, runtime verification, and destruction record exist.
