# Five-minute demonstration

## Before the recording

Run `task local:up` and `task local:verify`. Open terminal tabs for status and the three port-forwards. Never expose admin passwords or repository tokens on screen.

## Walkthrough

1. **00:00–00:35 — Three pillars.** Show the README competency table: DevOps, DevSecOps, and Cloud Security.
2. **00:35–01:10 — Security gates.** Show CodeQL, Trivy IaC, Gitleaks, OpenTofu tests, and the protected-branch checks.
3. **01:10–01:50 — Immutable release.** Show the digest, container scan, SBOM, Cosign signature, SLSA L2 provenance, and GitOps commit.
4. **01:50–02:30 — GitOps and runtime.** Show Argo `Synced/Healthy`, two pods, `/health/ready`, and `/metrics`.
5. **02:30–03:10 — Policy.** Show PSS `restricted`, quota/limits, then server-dry-run the unsigned fixture and show Kyverno rejecting it.
6. **03:10–03:50 — Cloud security without spend.** Show the mocked OpenTofu assertions and explicit EKS logs, VPC Flow Logs, KMS, IMDSv2, OIDC role split, and access entry. State clearly that AWS was not deployed.
7. **03:50–04:30 — Observability.** Open Grafana and the Prometheus target; point to the three alert rules.
8. **04:30–05:00 — Recovery.** Delete one pod, show replacement, patch replicas, show Argo self-heal, and finish with verified rollback.

Do not claim AWS was deployed unless a real plan/apply run is available. The repository proves AWS syntax, validation, mocked planning behavior, role separation, and safe lifecycle without requiring cloud spend.
