# Competency evidence matrix

| Competency | Repository evidence | Reproducible proof |
|---|---|---|
| Python API quality | `app/src`, strict mypy/Ruff, locked dependencies, pytest configuration | `task app:check` |
| Container hardening | Multi-stage digest-pinned `Dockerfile`, UID 10001, no-root runtime | Inspect built image and run with `--read-only` |
| Kubernetes packaging | Schema-backed Helm chart with probes, resources, PDB, HPA, topology spread | `task helm:check` |
| GitOps | Argo app-of-apps, two AppProjects, multi-source digest values, self-heal | `task local:verify` |
| Policy as code | PSS labels, Kyverno hardening and keyless image verification, eight CLI cases | CI `Helm, Kubernetes, and Kyverno` job |
| CI/CD | Parallel gates, immutable Action SHAs, release/promotion/rollback workflows | GitHub Actions run history |
| Static and IaC analysis | CodeQL `security-extended`, Trivy IaC misconfiguration gate, full-history Gitleaks | `CodeQL` and `IaC misconfiguration scan` checks |
| Supply-chain security | Trivy gate, Syft SPDX SBOM, Cosign keyless signature, GitHub provenance | `scripts/verify-artifact.sh` against a released digest |
| Observability | Prometheus metrics, ServiceMonitor, dashboard ConfigMap, three alert rules | `task local:verify` plus Grafana port-forward |
| Resilience | Two replicas, PDB, topology spreading, pod replacement, Argo drift correction | Destructive checks inside `task local:verify` |
| Cloud security | KMS state/secrets encryption, explicit EKS access, service-specific OIDC roles, audit/flow logs, IMDSv2, encrypted nodes | `task tofu:check` and `task security:check` without an AWS account |
| Infrastructure as code | Retained S3 bootstrap, pinned VPC/EKS modules, mocked security assertions | `task tofu:check` |
| Operational readiness | Status/log/port-forward tasks, seven runbooks, ADRs, threat model | Follow `docs/demo.md` from a clean clone |

## Validated evidence

The repository continuously validates:

- six parallel CI quality and security jobs;
- CodeQL with the `security-extended` query suite;
- multi-architecture release, vulnerability gate, SBOM, keyless signing,
  provenance verification, and GitOps promotion;
- fresh-cluster bootstrap, acceptance checks, and isolated-cluster teardown;
- API, Argo CD, policy, Prometheus target, pod recreation, and self-healing;
- OpenTofu formatting, validation, mocked security tests, and Trivy IaC checks
  without claiming an AWS deployment.

### Versioned Grafana dashboard

![DevSecOps Demo API dashboard with request rate and p95 latency](screenshots/grafana-dashboard.png)

### Kyverno negative control

The fresh-cluster E2E workflow submits the deliberately unsigned digest defined in `platform/policies/tests/unsigned-pod.yaml` using a server-side dry run. The test succeeds only when Kyverno rejects it. The expected error remains in the workflow logs rather than being displayed as a failing deployment screenshot.

Screenshots are committed only after successful validation of this repository. No placeholder, mock dashboard, or fabricated policy response is used.
